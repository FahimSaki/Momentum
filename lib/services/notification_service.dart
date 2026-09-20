import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:momentum/config/api_base_url.dart';
import 'package:momentum/models/app_notification.dart';

/// REST-only: fetches and updates the in-app notification list
/// (`/notifications`). FCM registration and local-notification display
/// live in `PushNotificationService` instead — a separate class with a
/// separate instance, since nothing here needs Firebase.
class NotificationService {
  final Logger _logger = Logger();
  String? _jwtToken;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_jwtToken',
    'Content-Type': 'application/json',
  };

  /// Sets the auth token used by the notification-list endpoints below.
  void updateToken(String jwtToken) {
    _jwtToken = jwtToken;
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notifications'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> notificationsList;
        if (responseData is Map<String, dynamic>) {
          notificationsList = responseData['notifications'] ?? [];
        } else if (responseData is List) {
          notificationsList = responseData;
        } else {
          return [];
        }

        return notificationsList
            .map((json) => AppNotification.fromJson(json))
            .toList();
      } else {
        _logger.e('Error fetching notifications: ${response.statusCode}');
        return [];
      }
    } catch (e, st) {
      _logger.e('Error fetching notifications', error: e, stackTrace: st);
      return [];
    }
  }

  Future<AppNotification?> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          if (data['notification'] != null) {
            return AppNotification.fromJson(data['notification']);
          }
        } catch (_) {
          // Parsing failed – caller will fall back to a local update
        }
        return null;
      }

      throw Exception('Failed to mark notification as read');
    } catch (e, st) {
      _logger.e('Error marking notification as read', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/notifications/mark-all-read'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e, st) {
      _logger.e(
        'Error marking all notifications as read',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
