import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/config/api_base_url.dart';
import 'package:momentum/models/user.dart';
import 'package:logger/logger.dart';

class UserService {
  final String jwtToken;
  final Logger _logger = Logger();

  UserService({required this.jwtToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };

  Future<List> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/search?q=$query&limit=20'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((u) => User.fromJson(u)).toList();
      }
      throw Exception('Failed to search users');
    } catch (e, st) {
      _logger.e('Error searching users', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future getUserByInviteId(String inviteId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/invite/$inviteId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
      throw Exception('User not found');
    } catch (e, st) {
      _logger.e('Error getting user by invite ID', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<User> getCurrentUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/profile'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get user profile');
    } catch (e, st) {
      _logger.e('Error getting user profile', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future updatePrivacySettings({
    required bool isPublic,
    required Map profileVisibility,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/users/profile'),
        headers: _headers,
        body: json.encode({
          'isPublic': isPublic,
          'profileVisibility': profileVisibility,
        }),
      );
      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to update privacy settings');
    } catch (e, st) {
      _logger.e('Error updating privacy settings', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> enableTwoFactor() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/2fa/enable'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to enable 2FA');
      }
    } catch (e, st) {
      _logger.e('Error enabling 2FA', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> disableTwoFactor() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/2fa/disable'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to disable 2FA');
      }
    } catch (e, st) {
      _logger.e('Error disabling 2FA', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> requestAccountDeletion() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/request-account-deletion'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to send verification code');
      }
    } catch (e, st) {
      _logger.e('Error requesting account deletion', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> confirmAccountDeletion(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/confirm-account-deletion'),
        headers: _headers,
        body: json.encode({'code': code}),
      );
      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to delete account');
      }
    } catch (e, st) {
      _logger.e('Error confirming account deletion', error: e, stackTrace: st);
      rethrow;
    }
  }
}
