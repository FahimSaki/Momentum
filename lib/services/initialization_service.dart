import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:momentum/services/realtime_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class InitializationService {
  static const notificationChannelId = 'tasks_channel';
  static const notificationId = 888;

  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!kIsWeb) {
      // Request notification permissions first
      await _requestNotificationPermissions();
      // Initialize background service
      await _initializeBackgroundService();
    }

    // Initialize RealtimeService (already kIsWeb safe)
    final realtimeService = RealtimeService();
    await realtimeService.init();
  }

  static Future<void> _initializeBackgroundService() async {
    if (kIsWeb) return;

    final service = FlutterBackgroundService();

    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'Task Tracker Service',
      description: 'Keeps track of your tasks in background',
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
        autoStartOnBoot: true,
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
    WidgetsFlutterBinding.ensureInitialized();
    Timer? periodicTimer;

    try {
      _logger.i('Background service started/resumed');

      periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (service is AndroidServiceInstance &&
            await service.isForegroundService()) {
          await flutterLocalNotificationsPlugin.show(
            notificationId,
            'Momentum',
            'Running: ${DateTime.now()}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                notificationChannelId,
                'MY FOREGROUND SERVICE',
                channelDescription: 'Shows background service status',
                icon: '@mipmap/ic_launcher',
                ongoing: true,
                importance: Importance.low,
              ),
            ),
          );
        }
      });

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: androidSettings);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      const androidChannel = AndroidNotificationChannel(
        notificationChannelId,
        'Tasks',
        description: 'Notifications for new tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      Timer.periodic(const Duration(minutes: 15), (_) {
        _logger.d('Background service health check running');
        service.invoke('debug', {
          'isRunning': true,
          'deviceId': deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      service.on('stop_service').listen((event) {
        periodicTimer?.cancel();
        service.stopSelf();
      });

      return true;
    } catch (e, stack) {
      periodicTimer?.cancel();
      _logger.e('Error in background service', error: e, stackTrace: stack);
      return false;
    }
  }

  static Future<void> _requestNotificationPermissions() async {
    if (kIsWeb) return;

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

    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }
}
