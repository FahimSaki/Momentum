import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Logger instance
  final Logger _logger = Logger();

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
    } catch (e, stacktrace) {
      _logger.e('Notification service initialization error',
          error: e, stackTrace: stacktrace);
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
    } catch (e, stackTrace) {
      _logger.e('Error showing notification', error: e, stackTrace: stackTrace);
    }
  }
}
