import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String backendUrl = apiBaseUrl;
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';

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

      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    } else {
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

      return {
        'success': true,
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    } else {
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      } catch (e) {
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
  }

  // Get stored authentication data
  static Future<Map<String, dynamic>?> getStoredAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_jwtTokenKey);
      final userId = prefs.getString(_userIdKey);
      final userDataJson = prefs.getString(_userDataKey);

      if (token != null && userId != null && userDataJson != null) {
        return {
          'token': token,
          'userId': userId,
          'user': json.decode(userDataJson),
        };
      }
    } catch (e) {
      // If there's any error reading stored data, return null
      print('Error reading stored auth data: $e');
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
  }

  // Validate token with server (optional - for extra security)
  static Future<bool> validateToken() async {
    try {
      final authData = await getStoredAuthData();
      if (authData == null) return false;

      // Make a simple authenticated request to verify token
      final response = await http.get(
        Uri.parse('$backendUrl/tasks/assigned?userId=${authData['userId']}'),
        headers: {'Authorization': 'Bearer ${authData['token']}'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }
}
