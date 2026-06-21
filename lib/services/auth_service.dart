import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:momentum/config/api_base_url.dart';

abstract class _AuthKeys {
  static const jwt = 'auth_jwt';
  static const userId = 'auth_user_id';
  static const userData = 'auth_user_data';
}

typedef JwtCallback = Future<void> Function(String jwt);

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static final Logger _logger = Logger();

  // GOOGLE_CLIENT_ID from Firebase Console → Authentication → Google → Web client ID
  static const String _googleClientId =
      '213940967151-bju2m1cc7b7vnflibkb6hb6j0h2a1ug9.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _googleClientId : null,
    serverClientId: kIsWeb ? null : _googleClientId,
  );

  final List<JwtCallback> _jwtListeners = [];

  void onJwtAvailable(JwtCallback cb) => _jwtListeners.add(cb);

  // ── Register ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
  ) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
            'name': name.trim(),
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Returns {requiresVerification: true, email: '...'}
      return data;
    }

    _logger.e('Registration failed: ${response.body}');
    throw Exception(_safeDecodeError(response.body));
  }

  // ── Login ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 45));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 403 && data['requiresVerification'] == true) {
      return {'requiresVerification': true, 'email': data['email']};
    }

    if (response.statusCode == 200 && data['requiresTwoFactor'] == true) {
      return {'requiresTwoFactor': true, 'email': data['email']};
    }

    if (response.statusCode == 200 && data['token'] != null) {
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    _logger.e('Login failed: ${response.body}');
    throw Exception(_safeDecodeError(response.body));
  }

  // ── Verify email OTP ────────────────────────────────────────────────────────

  Future<void> verifyEmail(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/verify-email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(_safeDecodeError(response.body));
    }
  }

  // ── Resend verification code ─────────────────────────────────────────────────

  Future<void> resendVerification(String email) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/resend-verification'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(_safeDecodeError(response.body));
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> googleSignIn() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');

    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    throw Exception(_safeDecodeError(response.body));
  }

  // ── Verify 2FA code ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> verify2FA(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/verify-2fa'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    throw Exception(_safeDecodeError(response.body));
  }

  // ── Stored auth data ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getStoredAuthData() async {
    try {
      final token = await _storage.read(key: _AuthKeys.jwt);
      final userId = await _storage.read(key: _AuthKeys.userId);
      final userDataJson = await _storage.read(key: _AuthKeys.userData);
      if (token == null || userId == null || userDataJson == null) return null;
      return {
        'token': token,
        'userId': userId,
        'user': jsonDecode(userDataJson),
      };
    } catch (e, st) {
      _logger.e('Error reading stored auth data', error: e, stackTrace: st);
      return null;
    }
  }

  Future<bool> validateToken() async {
    try {
      final authData = await getStoredAuthData();
      if (authData == null) return false;

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/auth/validate'),
            headers: {'Authorization': 'Bearer ${authData['token']}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _notifyListeners(authData['token'] as String);
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
      }
      return false;
    } catch (e, st) {
      _logger.e('Token validation error', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final token = await _storage.read(key: _AuthKeys.jwt);
      await Future.wait([
        _storage.delete(key: _AuthKeys.jwt),
        _storage.delete(key: _AuthKeys.userId),
        _storage.delete(key: _AuthKeys.userData),
      ]);
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      if (token != null) _notifyServerLogout(token);
    } catch (e, st) {
      _logger.e('Logout error', error: e, stackTrace: st);
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _persist(Map<String, dynamic> responseData) async {
    final token = responseData['token'] as String;
    final userId = responseData['user']['_id'] as String;
    final userData = jsonEncode(responseData['user']);

    await Future.wait([
      _storage.write(key: _AuthKeys.jwt, value: token),
      _storage.write(key: _AuthKeys.userId, value: userId),
      _storage.write(key: _AuthKeys.userData, value: userData),
    ]);

    _logger.i('Auth persisted for userId: $userId');
    await _notifyListeners(token);
  }

  Future<void> _notifyListeners(String jwt) async {
    for (final cb in _jwtListeners) {
      try {
        await cb(jwt);
      } catch (e) {
        _logger.w('JWT listener error: $e');
      }
    }
  }

  Future<void> _notifyServerLogout(String token) async {
    try {
      await http
          .post(
            Uri.parse('$apiBaseUrl/auth/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  String _safeDecodeError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final msg = data['message'] as String? ?? body;
      final errors = data['errors'];
      if (errors is List) return errors.join(', ');
      return msg;
    } catch (_) {
      return body;
    }
  }
}
