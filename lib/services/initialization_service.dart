import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class InitializationService {
  static const notificationChannelId = 'habits_channel';
  static const notificationId = 888;

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env");

    // Initialize background service first
    await _initializeBackgroundService();

    // Request notification permissions early
    await _requestNotificationPermissions();

    // Initialize Supabase with persistent connections
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      ***REMOVED*** dotenv.env['SUPABASE_ANON_KEY']!,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 2,
      ),
      storageOptions: const StorageClientOptions(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: true,
      ),
    );

    // Store last active timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active', DateTime.now().toIso8601String());

    // Initialize RealtimeService
    final realtimeService = RealtimeService();
    await realtimeService.init();

    // Initialize HabitDatabase
    await HabitDatabase.init();
  }

  static Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    // Create notification channel
    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'Habit Tracker Service',
      description: 'Keeps track of your habits in background',
      importance: Importance.low,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onBackgroundMessage,
        onBackground: _onBackgroundMessage,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundMessage,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Momentum',
        initialNotificationContent: 'Monitoring your tasks and habits',
        foregroundServiceNotificationId: notificationId,
      ),
    );

    await service.startService();

    // Replace default notification with custom icon
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Momentum',
      'Tracking your habits in the background',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_channel',
          'Habit Tracker',
          icon: '@drawable/ic_launcher',
          ongoing: true,
          importance: Importance.low,
          showWhen: true,
        ),
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onBackgroundMessage(ServiceInstance service) async {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications in background
    await _requestNotificationPermissions();

    // Create notification channel for background
    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'Habit Tracker Service',
      description: 'Keeps track of your habits in background',
      importance: Importance.high, // Changed to high
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    service.on('habit_created').listen((event) async {
      if (event != null) {
        final habitName = event['name'] as String;

        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecond, // Dynamic ID to prevent override
          'New Habit Created',
          'A new habit was created: $habitName',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'Habit Tracker',
              channelDescription: 'Notifications for new habits',
              importance: Importance.high,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              enableLights: true,
              icon: 'ic_launcher',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
          ),
        );
      }
    });

    return true;
  }

  static Future<void> _requestNotificationPermissions() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iOSSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
}
