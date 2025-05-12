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

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'Habit Tracker Service',
      description: 'Keeps track of your habits in background',
      importance: Importance.min,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundMessage,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Momentum',
        initialNotificationContent: 'Running in background',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onBackgroundMessage,
        onBackground: _onBackgroundMessage,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> _onBackgroundMessage(ServiceInstance service) async {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Supabase in background
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      ***REMOVED*** dotenv.env['SUPABASE_ANON_KEY']!,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 2,
      ),
    );

    // Set up realtime subscription
    final supabase = Supabase.instance.client;
    supabase.channel('habits_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'habits',
        callback: (payload) async {
          final habitName = payload.newRecord['name'] as String;

          await flutterLocalNotificationsPlugin.show(
            DateTime.now().millisecond,
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
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        },
      )
      ..subscribe();

    return true;
  }

  static Future<void> _requestNotificationPermissions() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
