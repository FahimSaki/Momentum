import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://localhost:5000/api/auth';

  Future<String?> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 201) {
      return null; // Success
    } else {
      return jsonDecode(response.body)['message'] ?? 'Registration failed';
    }
  }

  Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Save token using your preferred method (e.g., shared_preferences)
      // await saveToken(data['token']);
      return data['token'];
    } else {
      return jsonDecode(response.body)['message'] ?? 'Login failed';
    }
  }
}
