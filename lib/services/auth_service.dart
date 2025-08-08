import 'dart:convert';
import 'package:habit_tracker/constants/api_base_url.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String backendUrl = apiBaseUrl;

  // Login with email and password
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    print("📤 Sending login request to: $backendUrl/auth/login");

    final response = await http.post(
      Uri.parse('$backendUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    print("📥 Login response status: ${response.statusCode}");
    print("📄 Login response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Handle both '_id' and 'id' formats
      final userId = data['user']['_id'] ?? data['user']['id'];

      if (userId == null) {
        throw Exception('User ID not found in response');
      }

      return {
        'token': data['token'],
        'userId': userId,
        'user': data['user'],
      };
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // Register with email and password
  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    print("📤 Sending registration request to: $backendUrl/auth/register");

    final response = await http.post(
      Uri.parse('$backendUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    print("📥 Registration response status: ${response.statusCode}");
    print("📄 Registration response body: ${response.body}");

    // Accept both 200 (OK) and 201 (Created) as successful registration
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);

      // Handle both '_id' and 'id' formats for user ID
      final userId = data['user']['_id'] ?? data['user']['id'];

      if (userId == null) {
        throw Exception('User ID not found in registration response');
      }

      print("✅ Registration successful! User ID: $userId");

      return {
        'token': data['token'],
        'userId': userId,
        'user': data['user'],
      };
    } else {
      print("❌ Registration failed with status: ${response.statusCode}");
      throw Exception('Registration failed: ${response.body}');
    }
  }
}
