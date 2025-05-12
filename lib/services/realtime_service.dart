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
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  Future<void> init() async {
    try {
      // Get device ID
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }

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
    } catch (e, stack) {
      _logger.e('Error initializing RealtimeService',
          error: e, stackTrace: stack);
    }
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
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

  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
  }

  Future<void> _handleNewHabit(Map<String, dynamic> newRecord) async {
    try {
      final creatorDeviceId = newRecord['device_id'];

      // Only show notification if habit was created on another device
      if (creatorDeviceId != deviceId) {
        final habitName = newRecord['name'];
        await showNotification(habitName);
        _logger.d('Showing notification for new habit: $habitName');
      }
    } catch (e, stack) {
      _logger.e('Error handling new habit', error: e, stackTrace: stack);
    }
  }

  Future<void> showNotification(String habitName) async {
    const androidDetails = AndroidNotificationDetails(
      'habits_channel',
      'Habits',
      channelDescription: 'Notifications for new habits',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      'New Habit Created',
      'A new habit "$habitName" was created',
      notificationDetails,
    );
  }

  void _setupRealtimeSubscription() {
    // Create and configure the Realtime channel
    _habitsChannel = _supabase.channel('habits_channel');

    // Set up PostgresChanges listener
    _habitsChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'habits',
      callback: (payload) {
        _handleNewHabit(payload.newRecord);
      },
    );

    // Subscribe to the channel
    _habitsChannel.subscribe();
  }

  void dispose() {
    _habitsChannel.unsubscribe();
  }
}
