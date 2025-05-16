import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:async';

class InitializationService {
  static const notificationChannelId = 'habits_channel';
  static const notificationId = 888;

  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env");

    // Request notification permissions first
    await _requestNotificationPermissions();

    // Initialize background service
    await _initializeBackgroundService();

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
    // This will be executed in background
    WidgetsFlutterBinding.ensureInitialized();

    try {
      _logger.i('Background service started/resumed');
      // Initialize dotenv
      await dotenv.load(
          fileName: ".env"); // Get device ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';

      // Initialize Supabase in background with persistent connection
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        ***REMOVED*** dotenv.env['SUPABASE_ANON_KEY']!,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 1,
        ),
      );

      // Initialize notifications plugin in background
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: androidSettings);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Create notification channel for background
      const androidChannel = AndroidNotificationChannel(
        notificationChannelId,
        'Habits',
        description: 'Notifications for new habits',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Set up realtime subscription
      final supabase = Supabase.instance.client;
      final channel = supabase.channel('background_habits_channel');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'habits',
        callback: (payload) async {
          try {
            final habitName = payload.newRecord['name'] as String;
            final creatorDeviceId = payload.newRecord['device_id'] as String?;

            // Only show notification if created on a different device
            if (creatorDeviceId != deviceId) {
              await flutterLocalNotificationsPlugin.show(
                DateTime.now().millisecond,
                'New Habit Created',
                'Someone added: $habitName',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    notificationChannelId,
                    'Habits',
                    channelDescription: 'Notifications for new habits',
                    importance: Importance.max,
                    priority: Priority.high,
                    showWhen: true,
                    enableVibration: true,
                    enableLights: true,
                    playSound: true,
                    icon: '@mipmap/ic_launcher',
                    category: AndroidNotificationCategory.message,
                  ),
                ),
              );
            }
          } catch (e, stack) {
            _logger.e('Error showing notification',
                error: e, stackTrace: stack);
          }
        },
      );
      channel
          .subscribe(); // Periodic health check to keep service alive and monitor status
      Timer.periodic(const Duration(minutes: 15), (_) {
        _logger.d('Background service health check running');
        service.invoke('debug', {
          'isRunning': true,
          'deviceId': deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      // Keep the service alive
      service.on('stop_service').listen((event) {
        channel.unsubscribe();
        service.stopSelf();
      });

      return true;
    } catch (e, stack) {
      _logger.e('Error in background service', error: e, stackTrace: stack);
      return false;
    }
  }

  static Future<void> _requestNotificationPermissions() async {
    // Initialize notification plugin first
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

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();

      // Also request exact alarm permission if needed
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }
}
