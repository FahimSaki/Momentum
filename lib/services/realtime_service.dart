import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _supabase = Supabase.instance.client;
  late String deviceId;
  late RealtimeChannel _habitsChannel;
  final _notifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  Future<void> init() async {
    try {
      _logger.d('Initializing RealtimeService...');

      // Get device ID
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }

      // Request permissions first
      await _requestNotificationPermissions();

      // Initialize notifications
      await _initializeNotifications();

      // Register or update device using upsert
      await _supabase.from('devices').upsert(
        {
          'device_id': deviceId,
          'last_seen': DateTime.now().toIso8601String(),
        },
        onConflict: 'device_id', // Specify the unique column
      );

      // Set up realtime subscription
      _setupRealtimeSubscription();

      _logger.d('RealtimeService initialized');
    } catch (e, stack) {
      _logger.e('Error in RealtimeService init', error: e, stackTrace: stack);
    }
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13 and above
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      _logger.d('Android notification permission granted: $granted');
    }
  }

  Future<void> _initializeNotifications() async {
    // Create the notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'habits_channel',
      'Habits',
      description: 'Notifications for new habits',
      importance: Importance.high,
    );

    // Create the channel on the device
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _logger.d('Notification tapped: ${details.payload}');
      },
    );

    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> showNotification(String habitName) async {
    try {
      _logger.d('Showing notification for habit: $habitName');

      String title;
      String body;

      // Customize notification based on habit name
      if (habitName.toLowerCase().contains('fahim') ||
          habitName.toLowerCase().contains('saki')) {
        title = '📩 Fahim Saki gave you a new task !!';
        body = '$habitName -  was added to your tasks';
      } else if (habitName.toLowerCase().contains('sadia')) {
        title = '📚 Fahim Saki gave you a new task !!';
        body = 'Sadia was given these tasks: $habitName';
      } else {
        title = '✨ You were given a task !!';
        body = 'Start tracking: $habitName';
      }

      const androidDetails = AndroidNotificationDetails(
        'habits_channel',
        'Habits',
        channelDescription: 'Notifications for new habits',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''), // Enable expanded text
        enableLights: true,
        playSound: true,
        enableVibration: true,
      );

      await _notifications.show(
        DateTime.now().millisecond,
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: habitName,
      );

      _logger.d('Notification shown with title: $title');
    } catch (e, stack) {
      _logger.e('Error showing notification', error: e, stackTrace: stack);
    }
  }

  void _setupRealtimeSubscription() {
    _logger.d('Setting up realtime subscription...');

    _habitsChannel = _supabase.channel('habits_channel');

    _habitsChannel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'habits',
      callback: (payload) async {
        _logger.d('Received habit change: ${payload.newRecord}');

        final creatorDeviceId = payload.newRecord['device_id'] as String?;
        final habitName = payload.newRecord['name'] as String;

        _logger.d(
          'Creator device ID: $creatorDeviceId, Current device ID: $deviceId',
        );

        if (creatorDeviceId != null && creatorDeviceId != deviceId) {
          await showNotification(habitName);
        }
      },
    )
        .subscribe((status, [error]) {
      if (error != null) {
        _logger.e('Error subscribing to channel', error: error);
      } else {
        _logger.d('Successfully subscribed to channel: $status');
      }
    });
  }

  void dispose() {
    _habitsChannel.unsubscribe();
  }
}
