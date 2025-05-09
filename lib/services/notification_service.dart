import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
      },
    );
  }

  Future<void> showNewHabitNotification(String habitName, bool isRemote) async {
    const androidDetails = AndroidNotificationDetails(
      'habit_tracker_channel',
      'Habit Tracker Notifications',
      channelDescription: 'Notifications for new habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      channelShowBadge: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    final title = isRemote
        ? 'New Habit Added on Another Device!'
        : 'Fahim Saki gave you a task!';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      'New task: $habitName',
      notificationDetails,
    );
  }
}
