import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  late String deviceId;
  final _notifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

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
      } else {
        deviceId = 'unknown';
      }

      // Store device ID in SharedPreferences for background service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', deviceId);

      // Request permissions
      await _requestNotificationPermissions();

      // Initialize notifications
      await _initializeNotifications();

      // Register or update device using backend REST API
      await registerDeviceWithBackend();

      _isInitialized = true;
      _logger.d('RealtimeService initialized');
    } catch (e, stack) {
      _logger.e('Error in RealtimeService init', error: e, stackTrace: stack);
    }
  }

  Future<void> registerDeviceWithBackend() async {
    try {
      // Replace with your backend URL
      const backendUrl = 'http://10.0.2.2:5000/devices/register';
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'last_seen': DateTime.now().toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        _logger.d('Device registered with backend');
      } else {
        _logger.e('Failed to register device: \\${response.body}');
      }
    } catch (e, stack) {
      _logger.e('Error registering device', error: e, stackTrace: stack);
    }
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
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
        _logger.d('Notification tapped: \\${details.payload}');
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

  void dispose() {
    _isInitialized = false;
  }
}
