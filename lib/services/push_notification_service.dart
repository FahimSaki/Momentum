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

// ── Web Push (VAPID) key ───────────────────────────────────────────────────
const String _webVapidKey =
    'BGUgFaghX7Er_jdcK59JEYoP2hU0OURgms1ct2PJgV23KpJj71CxiCnrRJxwrBs5eRk8DZ4IlZxNwFKrXwFJs5I';

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
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM-BG] message: ${message.messageId}, '
    'title: ${message.notification?.title}',
  );
}

/// FCM + local-notification setup only. The REST notification-list calls
/// (getNotifications/markAsRead/markAllAsRead) live in the separate,
/// REST-only `NotificationService` instead.
class PushNotificationService {
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

    try {
      await _initLocalNotifications();

      if (!_isFirebaseInitialized) {
        _isFirebaseInitialized = true;

        _initFirebaseMessaging().catchError((e, st) {
          _logger.w(
            'FCM initialization failed (non-critical)',
            error: e,
            stackTrace: st,
          );
        });
      } else {
        _registerToken().catchError((e, st) {
          _logger.w(
            'FCM token registration failed (non-critical)',
            error: e,
            stackTrace: st,
          );
        });
      }
    } catch (e, st) {
      _logger.w(
        'PushNotificationService init failed (non-critical)',
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

    if (!kIsWeb) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);
    }
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

    if (!kIsWeb) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
    }

    await _registerToken();

    _onTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      _logger.i('FCM token refreshed');
      await _sendTokenToBackend(token);
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

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

      if (kIsWeb && _webVapidKey.startsWith('REPLACE_WITH')) {
        _logger.w(
          'No web VAPID key configured — skipping FCM token fetch on web. '
          'Set _webVapidKey in push_notification_service.dart (Firebase '
          'Console → Cloud Messaging → Web Push certificates).',
        );
        return;
      }

      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
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

    _logger.i('PushNotificationService disposed');
  }
}
