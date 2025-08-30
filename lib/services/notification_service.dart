import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();
  
  FirebaseMessaging? _messaging;
  String? _jwtToken;
  bool _isInitialized = false;

  // Initialize notification service
  Future<void> init({String? jwtToken}) async {
    if (_isInitialized) return;

    _jwtToken = jwtToken;

    try {
      // Initialize local notifications
      if (!kIsWeb) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // Create notification channel
        const androidChannel = AndroidNotificationChannel(
          'momentum_notifications',
          'Momentum Notifications',
          description: 'Task and team notifications',
          importance: Importance.high,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      // Initialize Firebase messaging
      if (!kIsWeb) {
        _messaging = FirebaseMessaging.instance;
        await _requestPermission();
        await _setupFCM();
      }

      _isInitialized = true;
      _logger.i('✅ Notification service initialized');
    } catch (e, stackTrace) {
      _logger.e('Notification service initialization error', error: e, stackTrace: stackTrace);
    }
  }

  // Request notification permission
  Future<void> _requestPermission() async {
    if (kIsWeb || _messaging == null) return;

    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _logger.i('Notification permission: ${settings.authorizationStatus}');
  }

  // Setup FCM
  Future<void> _setupFCM() async {
    if (kIsWeb || _messaging == null || _jwtToken == null) return;

    try {
      // Get FCM token
      final token = await _messaging!.getToken();
      if (token != null) {
        await _updateFCMToken(token);
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        _updateFCMToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _logger.i('✅ FCM setup complete');
    } catch (e, stackTrace) {
      _logger.e('FCM setup error', error: e, stackTrace: stackTrace);
    }
  }

  // Update FCM token on server
  Future<void> _updateFCMToken(String token) async {
    if (_jwtToken == null) return;

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/notifications/fcm-token'),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': token,
          'platform': kIsWeb ? 'web' : 'android',
        }),
      );

      _logger.i('✅ FCM token updated on server');
    } catch (e) {
      _logger.e('Error updating FCM token: $e');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i('Received foreground message: ${message.messageId}');

    if (!kIsWeb) {
      await _showLocalNotification(message);
    }
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    Logger().i('Received background message: ${message.messageId}');
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    _logger.i('Notification tapped: ${message.data}');
    _processNotificationAction(message.data);
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _processNotificationAction(data);
      } catch (e) {
        _logger.e('Error processing notification payload: $e');
      }
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'momentum_notifications',
      'Momentum Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Momentum',
      message.notification?.body ?? 'New notification',
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  // Process notification action (navigation, etc.)
  void _processNotificationAction(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'task_assigned':
        // Navigate to task details
        break;
      case 'task_completed':
        // Navigate to task or team page
        break;
      case 'team_invitation':
        // Navigate to invitations page
        break;
      default:
        // Default action
        break;
    }
  }

  // Get notifications from server
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    if (_jwtToken == null) return [];

    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'unreadOnly': unreadOnly.toString(),
      };

      final uri = Uri.parse('$apiBaseUrl/notifications')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_jwtToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = (data['notifications'] as List)
            .map((notif) => AppNotification.fromJson(notif))
            .toList();

        return notifications;
      } else {
        _logger.e('Error fetching notifications: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching notifications', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_jwtToken == null) return;

    try {
      await http.put(
        Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
        headers: {'Authorization': 'Bearer $_jwtToken'},
      );
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_jwtToken == null) return;

    try {
      await http.put(
        Uri.parse('$apiBaseUrl/notifications/read-all'),
        headers: {'Authorization': 'Bearer $_jwtToken'},
      );
    } catch (e) {
      _logger.e('Error marking all notifications as read: $e');
    }
  }

  // Update JWT token
  void updateJwtToken(String token) {
    _jwtToken = token;
    if (_isInitialized && !kIsWeb) {
      _setupFCM(); // Re-setup FCM with new token
    }
  }
} == 201) {
        final data = json.decode(response.body);
        return Team.fromJson(data['team']);
      } else {
        _logger.e('Error creating team: ${response.body}');
        throw Exception('Failed to create team: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get user's teams
  Future<List<Team>> getUserTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((team) => Team.fromJson(team)).toList();
      } else {
        _logger.e('Error fetching teams: ${response.body}');
        throw Exception('Failed to fetch teams');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching teams', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get team details
  Future<Team> getTeamDetails(String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams/$teamId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Team.fromJson(data);
      } else {
        _logger.e('Error fetching team details: ${response.body}');
        throw Exception('Failed to fetch team details');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching team details', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Invite user to team
  Future<void> inviteToTeam({
    required String teamId,
    required String email,
    String role = 'member',
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams/$teamId/invite'),
        headers: _headers,
        body: json.encode({
          'email': email,
          'role': role,
          'message': message,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to invite user');
      }
    } catch (e, stackTrace) {
      _logger.e('Error inviting user to team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get pending invitations
  Future<List<TeamInvitation>> getPendingInvitations() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams/invitations/pending'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((invitation) => TeamInvitation.fromJson(invitation)).toList();
      } else {
        _logger.e('Error fetching invitations: ${response.body}');
        throw Exception('Failed to fetch invitations');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching invitations', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Respond to team invitation
  Future<void> respondToInvitation(String invitationId, String response) async {
    try {
      final httpResponse = await http.put(
        Uri.parse('$apiBaseUrl/teams/invitations/$invitationId/respond'),
        headers: _headers,
        body: json.encode({'response': response}),
      );

      if (httpResponse.statusCode != 200) {
        final errorData = json.decode(httpResponse.body);
        throw Exception(errorData['message'] ?? 'Failed to respond to invitation');
      }
    } catch (e, stackTrace) {
      _logger.e('Error responding to invitation', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Update team settings
  Future<void> updateTeamSettings(String teamId, Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/teams/$teamId/settings'),
        headers: _headers,
        body: json.encode({'settings': settings}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update team settings');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating team settings', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Remove team member
  Future<void> removeTeamMember(String teamId, String memberId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/teams/$teamId/members/$memberId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to remove team member');
      }
    } catch (e, stackTrace) {
      _logger.e('Error removing team member', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Leave team
  Future<void> leaveTeam(String teamId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams/$teamId/leave'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to leave team');
      }
    } catch (e, stackTrace) {
      _logger.e('Error leaving team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Delete team
  Future<void> deleteTeam(String teamId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/teams/$teamId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete team');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  