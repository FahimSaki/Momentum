import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String backendUrl = 'http://10.0.2.2:5000'; // Change if needed

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
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // Register with email and password
  static Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$backendUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('Registration failed: ${response.body}');
    }
  }
}
