import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String backendUrl = apiBaseUrl;

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
      // data should contain { token: ..., user: { _id: ..., ... } }
      return {
        'token': data['token'],
        'userId': data['user']['_id'], // Your backend uses _id
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

    // Your backend returns 201 Created for successful registration
    if (response.statusCode == 201) {
      final data = json.decode(response.body);

      // Your backend returns the user object with _id field
      return {
        'success': true,
        'token': data['token'],
        'userId': data['user']['_id'], // Changed from 'id' to '_id'
        'user': data['user'],
      };
    } else {
      // Parse error message from your backend
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      } catch (e) {
        throw Exception('Registration failed: ${response.body}');
      }
    }
  }
}
