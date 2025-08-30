import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/app_notification.dart';

class NotificationService {
  final Logger _logger = Logger();
  String? _jwtToken;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_jwtToken',
    'Content-Type': 'application/json',
  };

  // Initialize service (can be called without Firebase on web)
  Future<void> init({String? jwtToken}) async {
    try {
      _jwtToken = jwtToken;
      _logger.i('NotificationService initialized');

      // Only initialize Firebase messaging on mobile platforms
      if (!kIsWeb) {
        await _initializeFirebaseMessaging();
      } else {
        _logger.i('Firebase messaging disabled on web platform');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error initializing NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Firebase initialization (mobile only)
  Future<void> _initializeFirebaseMessaging() async {
    if (kIsWeb) return;

    try {
      // Note: Firebase messaging functionality would go here
      // For now, we'll just log that it's initialized
      _logger.i('Firebase messaging would be initialized here (mobile only)');
    } catch (e, stackTrace) {
      _logger.w(
        'Firebase messaging initialization failed (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Get user notifications
  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notifications'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        _logger.e(
          'Error fetching notifications: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to fetch notifications');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error fetching notifications',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e(
          'Error marking notification as read: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to mark notification as read');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error marking notification as read',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/notifications/read-all'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e(
          'Error marking all notifications as read: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error marking all notifications as read',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Send notification (admin/system use)
  Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    String? teamId,
    String? taskId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final body = {
        'recipientId': recipientId,
        'type': type,
        'title': title,
        'message': message,
        if (teamId != null) 'teamId': teamId,
        if (taskId != null) 'taskId': taskId,
        if (data != null) 'data': data,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/notifications'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        _logger.e(
          'Error sending notification: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to send notification');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending notification', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Handle Firebase token refresh (mobile only)
  Future<void> refreshFirebaseToken() async {
    if (kIsWeb) return;

    try {
      // Firebase token refresh logic would go here
      _logger.i('Firebase token refresh would be handled here (mobile only)');
    } catch (e, stackTrace) {
      _logger.w(
        'Error refreshing Firebase token (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Handle background message (mobile only)
  static Future<void> handleBackgroundMessage(
    Map<String, dynamic> message,
  ) async {
    if (kIsWeb) return;

    try {
      final Logger logger = Logger();
      logger.i('Background message received: $message');
      // Handle background notification logic here
    } catch (e) {
      final Logger logger = Logger();
      logger.e('Error handling background message', error: e);
    }
  }

  void dispose() {
    _logger.i('NotificationService disposed');
  }
}
