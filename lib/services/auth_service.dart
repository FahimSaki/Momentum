import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class AuthService {
  static const String backendUrl = apiBaseUrl;
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';

  static final Logger _logger = Logger();

  // Login with email and password
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$backendUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Save authentication data
      await _saveAuthData(
        token: data['token'],
        userId: data['user']['_id'],
        userData: data['user'],
      );

      _logger.i('Login successful for user: ${data['user']['_id']}');

      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    } else {
      _logger.e('Login failed: ${response.body}');
      throw Exception('Login failed: ${response.body}');
    }
  }

  // Register with email and password
  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$backendUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);

      // Save authentication data
      await _saveAuthData(
        token: data['token'],
        userId: data['user']['_id'],
        userData: data['user'],
      );

      _logger.i('Registration successful for user: ${data['user']['_id']}');

      return {
        'success': true,
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    } else {
      try {
        final errorData = json.decode(response.body);
        _logger.e('Registration failed: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Registration failed');
      } catch (e) {
        _logger.e('Registration failed with raw body: ${response.body}');
        throw Exception('Registration failed: ${response.body}');
      }
    }
  }

  // Save authentication data to persistent storage
  static Future<void> _saveAuthData({
    required String token,
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtTokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userDataKey, json.encode(userData));

    _logger.d('Auth data saved for userId: $userId');
  }

  // Get stored authentication data
  static Future<Map<String, dynamic>?> getStoredAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_jwtTokenKey);
      final userId = prefs.getString(_userIdKey);
      final userDataJson = prefs.getString(_userDataKey);

      if (token != null && userId != null && userDataJson != null) {
        _logger.d('Stored auth data found for userId: $userId');
        return {
          'token': token,
          'userId': userId,
          'user': json.decode(userDataJson),
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error reading stored auth data',
          error: e, stackTrace: stackTrace);
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final authData = await getStoredAuthData();
    return authData != null;
  }

  // Logout - clear stored authentication data
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userDataKey);

    _logger.i('User logged out and auth data cleared');
  }

  // Validate token with server (optional - for extra security)
  static Future<bool> validateToken() async {
    try {
      final authData = await getStoredAuthData();
      if (authData == null) return false;

      final response = await http.get(
        Uri.parse('$backendUrl/tasks/assigned?userId=${authData['userId']}'),
        headers: {'Authorization': 'Bearer ${authData['token']}'},
      );

      final valid = response.statusCode == 200;
      _logger.d(
          'Token validation result for userId ${authData['userId']}: $valid');
      return valid;
    } catch (e, stackTrace) {
      _logger.e('Token validation error', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
