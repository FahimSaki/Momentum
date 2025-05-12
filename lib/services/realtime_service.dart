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
    const androidChannel = AndroidNotificationChannel(
      'habits_channel', // Same channel ID as background service
      'Habits',
      description: 'Notifications for new habits',
      importance: Importance.high, // Change to high
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

  void _setupRealtimeSubscription() {
    _logger.d('Setting up realtime subscription with device ID: $deviceId');

    _habitsChannel = _supabase.channel('habits_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'habits',
        callback: (PostgresChangePayload payload) async {
          _logger.d('Received habit change: ${payload.newRecord}');

          final creatorDeviceId = payload.newRecord['device_id'] as String?;
          final habitName = payload.newRecord['name'] as String;

          // Only show notification if created on a different device
          if (creatorDeviceId != deviceId) {
            _logger.d('Showing notification for habit from different device');
            await showNotification(habitName);
          } else {
            _logger.d('Skipping notification for habit from same device');
          }
        },
      )
      ..subscribe((status, [error]) {
        _logger.d('Subscription status: $status, Error: $error');
      });
  }

  void dispose() {
    _habitsChannel.unsubscribe();
  }
}
