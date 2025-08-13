import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(initSettings);

      // Create notification channel
      const androidChannel = AndroidNotificationChannel(
        'tasks_channel',
        'Tasks',
        description: 'Task completion notifications',
        importance: Importance.high,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
    } catch (e) {
      print('Notification service initialization error: $e');
    }
  }

  Future<void> showTaskCompletionReminder() async {
    if (!_isInitialized || kIsWeb) return;

    try {
      await _notifications.show(
        0,
        'Daily Tasks',
        'Don\'t forget to complete your tasks today!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tasks_channel',
            'Tasks',
            channelDescription: 'Task completion notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
}
