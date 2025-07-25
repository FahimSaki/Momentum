import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _logger.d('Initializing RealtimeService...');

      // Only run on mobile platforms
      if (!kIsWeb) {
        await _requestNotificationPermissions();
        await _initializeNotifications();
      }

      _isInitialized = true;
      _logger.d('RealtimeService initialized');
    } catch (e, stack) {
      _logger.e('Error in RealtimeService init', error: e, stackTrace: stack);
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted =
        await androidImplementation?.requestNotificationsPermission();

    _logger.d('Android notification permission granted: $granted');
  }

  Future<void> _initializeNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'habits_channel',
      'Habits',
      description: 'Notifications for new habits',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _logger.d('Notification tapped: ${details.payload}');
      },
    );
  }

  Future<void> showNotification(String habitName) async {
    try {
      if (kIsWeb) {
        _logger.w('Notifications not supported on web');
        return;
      }

      _logger.d('Attempting to show notification for habit: $habitName');

      const androidDetails = AndroidNotificationDetails(
        'habits_channel',
        'Habits',
        channelDescription: 'Notifications for new habits',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.message,
      );

      await _notifications.show(
        DateTime.now().millisecond,
        'New Habit Added!',
        'Someone added: $habitName',
        const NotificationDetails(android: androidDetails),
      );

      _logger.d('Notification shown successfully');
    } catch (e, stack) {
      _logger.e('Error showing notification', error: e, stackTrace: stack);
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
