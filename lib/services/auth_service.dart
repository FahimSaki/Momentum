import 'dart:async';
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
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$backendUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email, // ✅ Required for login
        'password': password, // ✅ Required for login
        // ❌ NO name field needed for login
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

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

  // REGISTER - Requires name, email, and password
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name, // ✅ Required parameter for registration
  ) async {
    try {
      _logger.i("Attempting registration for: $email");

      final requestBody = {
        'email': email.trim().toLowerCase(), // ✅ Required
        'password': password, // ✅ Required
        'name': name.trim(), // ✅ Required for registration
      };

      _logger.d("Registration request body: ${json.encode(requestBody)}");

      final response = await http
          .post(
            Uri.parse('$backendUrl/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timeout - please try again'),
          );

      _logger.i("Registration response status: ${response.statusCode}");
      _logger.d("Registration response body: ${response.body}");

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

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
          'message': data['message'] ?? 'Registration successful',
        };
      } else {
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? 'Registration failed';

          if (errorData['errors'] is List) {
            errorMessage = (errorData['errors'] as List).join(', ');
          }
        } catch (e) {
          errorMessage = 'Registration failed: ${response.body}';
        }

        _logger.e('Registration failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      _logger.e('Registration error: $e');
      rethrow;
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
      _logger.e(
        'Error reading stored auth data',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final authData = await getStoredAuthData();
    return authData != null;
  }

  //  logout with proper cleanup
  static Future<void> logout() async {
    try {
      _logger.i('Starting logout process...');

      // Get current auth data before clearing (for server logout if needed)
      final authData = await getStoredAuthData();

      // Clear all stored authentication data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jwtTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userDataKey);

      // Optional: Clear all other app data if needed
      // await prefs.clear(); // Use this if you want to clear ALL stored data

      _logger.i('User logged out and auth data cleared');

      // Optional: Notify server about logout (if your backend supports it)
      if (authData != null) {
        try {
          await _notifyServerLogout(authData['token']);
        } catch (e) {
          _logger.w('Failed to notify server about logout (non-critical): $e');
          // Don't throw error here as local logout should still succeed
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error during logout', error: e, stackTrace: stackTrace);
      // Even if there's an error, try to clear the data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (clearError) {
        _logger.e(
          'Failed to clear prefs during error cleanup',
          error: clearError,
        );
      }
      rethrow;
    }
  }

  // Optional: Notify server about logout (implement if your backend supports it)
  static Future<void> _notifyServerLogout(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/auth/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5)); // Add timeout

      if (response.statusCode == 200) {
        _logger.d('Server notified about logout successfully');
      } else {
        _logger.w('Server logout notification failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('Server logout notification error: $e');
      // Don't rethrow - this is non-critical
    }
  }

  // Validate token with server (enhanced with better error handling)
  static Future<bool> validateToken() async {
    try {
      final authData = await getStoredAuthData();
      if (authData == null) {
        _logger.d('No auth data found for token validation');
        return false;
      }

      _logger.d('Validating token for userId: ${authData['userId']}');

      final response = await http
          .get(
            Uri.parse(
              '$backendUrl/tasks/assigned?userId=${authData['userId']}',
            ),
            headers: {'Authorization': 'Bearer ${authData['token']}'},
          )
          .timeout(const Duration(seconds: 10)); // Add timeout

      final valid = response.statusCode == 200;

      if (!valid) {
        _logger.w(
          'Token validation failed: ${response.statusCode} - ${response.body}',
        );
        // If token is invalid, clear stored data
        if (response.statusCode == 401 || response.statusCode == 403) {
          _logger.i('Token expired/invalid, clearing stored auth data');
          await logout();
        }
      } else {
        _logger.d('Token validation successful');
      }

      return valid;
    } catch (e, stackTrace) {
      _logger.e('Token validation error', error: e, stackTrace: stackTrace);

      // If it's a network error, don't clear the token (user might be offline)
      // If it's an auth error, clear the token
      if (e.toString().contains('401') || e.toString().contains('403')) {
        _logger.i('Auth error detected, clearing stored data');
        await logout();
      }

      return false;
    }
  }
}
