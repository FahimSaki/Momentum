import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
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
        Uri.parse('$apiBaseUrl/users/search?query=$query&limit=20'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((user) => User.fromJson(user)).toList();
      } else {
        _logger.e('Error searching users: ${response.body}');
        throw Exception('Failed to search users');
      }
    } catch (e, stackTrace) {
      _logger.e('Error searching users', error: e, stackTrace: stackTrace);
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
      } else {
        _logger.e('Error getting user by invite ID: ${response.body}');
        throw Exception('User not found');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error getting user by invite ID',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future getCurrentUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/profile'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        _logger.e('Error getting user profile: ${response.body}');
        throw Exception('Failed to get user profile');
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting user profile', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future updatePrivacySettings({
    required bool isPublic,
    required Map profileVisibility,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/users/privacy'),
        headers: _headers,
        body: json.encode({
          'isPublic': isPublic,
          'profileVisibility': profileVisibility,
        }),
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else {
        _logger.e('Error updating privacy settings: ${response.body}');
        throw Exception('Failed to update privacy settings');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating privacy settings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
