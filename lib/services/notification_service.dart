import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/app_notification.dart';

// ── Background message handler ────────────────────────────────────────────
// Must be a top-level function (not inside a class).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ── Android notification channel ──────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'momentum_notifications', // must match channelId in backend notificationService.js
  'Momentum Notifications',
  description: 'Task assignments, completions, and team invitations',
  importance: Importance.high,
  enableVibration: true,
  playSound: true,
);

class NotificationService {
  final Logger _logger = Logger();
  String? _jwtToken;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
      await _initFirebaseMessaging();
      _logger.i('NotificationService initialised');
    } catch (e, st) {
      // Non-fatal — app works fine without push notifications.
      _logger.w(
        'NotificationService init failed (non-critical)',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Local notifications setup ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // FIX: flutter_local_notifications v21 changed initialize() to use the
    // named parameter `settings:` instead of a positional argument.
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create the Android channel so high-priority messages appear as heads-up.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _logger.i('Local notification tapped: ${response.payload}');
  }

  // ── Firebase Messaging setup ──────────────────────────────────────────────

  Future<void> _initFirebaseMessaging() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _logger.i('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _logger.w('Push notifications denied by user');
      return;
    }

    await _registerToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _logger.i('FCM token refreshed');
      await _sendTokenToBackend(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      if (Platform.isIOS) {
        // APNS token must be available before FCM token on iOS.
        await FirebaseMessaging.instance.getAPNSToken();
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _logger.i('FCM token obtained');
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      _logger.w('Could not obtain FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    if (_jwtToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/notifications/fcm-token'),
        headers: _headers,
        body: json.encode({'token': token, 'platform': _platform()}),
      );

      if (response.statusCode == 200) {
        _logger.i('FCM token registered with backend');
      } else {
        _logger.w('FCM token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('Could not send FCM token to backend: $e');
    }
  }

  // FIX: use dart:io Platform directly — clean and unambiguous.
  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'android';
  }

  // ── Message handling ──────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i('FCM foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // FIX: flutter_local_notifications v21 changed show() to named parameters.
    // `id:` is now required and the old positional signature was removed.
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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

  // ── REST API (in-app notifications) ───────────────────────────────────────

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
        _logger.e('Error fetching notifications: ${response.statusCode}');
        return [];
      }
    } catch (e, st) {
      _logger.e('Error fetching notifications', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.put(
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
      final response = await http.put(
        Uri.parse('$apiBaseUrl/notifications/read-all'),
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

  void dispose() {
    _logger.i('NotificationService disposed');
  }
}
