import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:momentum/config/api_base_url.dart';
import 'package:momentum/firebase_options.dart';
import 'package:momentum/models/app_notification.dart';

// ── Android notification channel ──────────────────────────────────────────
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'momentum_high_importance',
  'Momentum Notifications',
  description: 'Task assignments, completions, and team invitations',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
  showBadge: true,
);

// ── Background message handler (MUST be top-level, not a class method) ────
// FIX: Do NOT show a local notification here. Because the backend sends
// messages with a `notification` field, FCM already shows the system banner
// automatically when the app is in the background or terminated. Showing a
// local notification here would produce a duplicate banner.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM-BG] message: ${message.messageId}, '
    'title: ${message.notification?.title}',
  );
  // FCM system handles the banner automatically — nothing else needed here.
}

class NotificationService {
  final Logger _logger = Logger();
  String? _jwtToken;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool _isFirebaseInitialized = false;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_jwtToken',
    'Content-Type': 'application/json',
  };

  // ── Public init ───────────────────────────────────────────────────────────

  Future<void> init({String? jwtToken}) async {
    _jwtToken = jwtToken;

    if (kIsWeb) {
      _logger.i('Push notifications disabled on web');
      return;
    }

    try {
      await _initLocalNotifications();

      if (!_isFirebaseInitialized) {
        await _initFirebaseMessaging();
        _isFirebaseInitialized = true;
      } else {
        // App already running — just make sure the token is current
        await _registerToken();
      }

      _logger.i('NotificationService initialised');
    } catch (e, st) {
      _logger.w(
        'NotificationService init failed (non-critical)',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Local notifications ───────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    // Create the high-importance channel on Android so WhatsApp-style
    // heads-up banners appear when the app is in the foreground.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _logger.i('Notification tapped (foreground): ${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Background notification tapped: ${response.payload}');
  }

  // ── Firebase Messaging ────────────────────────────────────────────────────

  Future<void> _initFirebaseMessaging() async {
    // NOTE: The top-level background handler is registered once in main.dart
    // BEFORE Firebase.initializeApp(). Do NOT register it again here.

    // Request permission (iOS + Android 13+)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    _logger.i('FCM permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _logger.w('Push notifications denied by user');
      return;
    }

    // FIX: Disable iOS auto-display of FCM banner in foreground.
    // Without this, iOS would show the FCM banner AND our local notification
    // banner simultaneously — two banners for one event.
    // The local notification in _handleForegroundMessage handles the banner
    // on both Android and iOS when the app is open.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false, // local notification handles this
          badge: true, // still update the app badge count
          sound: false, // local notification handles this
        );

    await _registerToken();

    // ── Listeners ─────────────────────────────────────────────────────────

    _onTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      _logger.i('FCM token refreshed');
      await _sendTokenToBackend(token);
    });

    // App is OPEN (foreground) — FCM does NOT show a banner automatically
    // on Android, and we disabled it on iOS above. Show one ourselves so
    // the user still gets a WhatsApp-style heads-up banner.
    _onMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // App was in BACKGROUND, user tapped the notification.
    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    // App was TERMINATED, user tapped the notification.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _logger.i(
        'App opened from terminated state via notification: '
        '${initialMessage.messageId}',
      );
      _handleNotificationTap(initialMessage);
    }
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // APNS token must exist before FCM token is available on iOS.
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 2));
        }
        if (apnsToken == null) {
          _logger.w('APNS token still null after retries — skipping FCM reg');
          return;
        }
        _logger.i('APNS token obtained');
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _logger.i('FCM token: ${token.substring(0, 20)}...');
        await _sendTokenToBackend(token);
      } else {
        _logger.w('FCM getToken() returned null');
      }
    } catch (e, st) {
      _logger.w('Could not obtain FCM token', error: e, stackTrace: st);
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    if (_jwtToken == null) {
      _logger.w('No JWT — cannot register FCM token yet');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/users/fcm-token'),
            headers: _headers,
            body: json.encode({'token': token, 'platform': _platform()}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.i('FCM token registered with backend ✅');
      } else {
        _logger.w(
          'FCM token registration failed: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (e, st) {
      _logger.w(
        'Could not send FCM token to backend',
        error: e,
        stackTrace: st,
      );
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'android';
  }

  // ── Message handlers ──────────────────────────────────────────────────────

  /// App is in the FOREGROUND — show a WhatsApp-style heads-up banner via
  /// local notifications. This handles both Android (FCM never auto-shows
  /// in foreground) and iOS (we disabled FCM auto-show above to prevent
  /// duplicates).
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i(
      'FCM foreground: ${message.messageId} '
      'title="${message.notification?.title}"',
    );

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          fullScreenIntent: false,
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            htmlFormatBigText: false,
            contentTitle: notification.title,
            htmlFormatContentTitle: false,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    _logger.i('Notification tapped: type=${message.data['type']}');
    // Add any navigation logic here based on message.data['type']
  }

  // ── REST API ──────────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notifications'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> notificationsList;
        if (responseData is Map<String, dynamic>) {
          notificationsList = responseData['notifications'] ?? [];
        } else if (responseData is List) {
          notificationsList = responseData;
        } else {
          return [];
        }

        return notificationsList
            .map((json) => AppNotification.fromJson(json))
            .toList();
      } else {
        _logger.e(
          'Error fetching notifications: '
          '${response.statusCode}',
        );
        return [];
      }
    } catch (e, st) {
      _logger.e('Error fetching notifications', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e, st) {
      _logger.e('Error marking notification as read', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/notifications/mark-all-read'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e, st) {
      _logger.e(
        'Error marking all notifications as read',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();

    _onMessageSub = null;
    _onMessageOpenedAppSub = null;
    _onTokenRefreshSub = null;
    _isFirebaseInitialized = false;

    _logger.i('NotificationService disposed');
  }
}
