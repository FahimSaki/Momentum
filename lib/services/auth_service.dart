import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:momentum/config/api_base_url.dart';

/// Keys used by [AuthService] in [FlutterSecureStorage].
/// These are the ONLY keys used for JWT/auth storage.
/// [SharedPreferences] is no longer used for auth data.
abstract class _AuthKeys {
  static const jwt = 'auth_jwt';
  static const userId = 'auth_user_id';
  static const userData = 'auth_user_data';
}

/// Callback type that services can register to be notified when
/// a fresh JWT is available (e.g. after login or token refresh).
typedef JwtCallback = Future<void> Function(String jwt);

/// Single source of truth for authentication.
///
/// Responsibilities:
///   - Login / Register / Logout via backend
///   - Store JWT **only** in [FlutterSecureStorage]
///   - Notify registered listeners when a JWT is available
///     so other services (NotificationService, etc.) can init
///     themselves without the UI knowing about it
class AuthService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Private state ──────────────────────────────────────────────────────────
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static final Logger _logger = Logger();

  /// Listeners notified with the JWT string whenever a valid JWT is obtained
  /// (on login, register, or successful cold-start validation).
  final List<JwtCallback> _jwtListeners = [];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Register a callback that fires whenever a JWT becomes available.
  /// Use this in [NotificationService] and [InitializationService] instead
  /// of reading storage directly.
  void onJwtAvailable(JwtCallback cb) => _jwtListeners.add(cb);

  /// Login with email + password. Returns `{'token', 'userId', 'user'}`.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    _logger.e('Login failed: ${response.body}');
    final body = _safeDecodeError(response.body);
    throw Exception(body);
  }

  /// Register a new account. Returns same shape as [login].
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
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _persist(data);
      return {
        'success': true,
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
        'message': data['message'] ?? 'Registration successful',
      };
    }

    _logger.e('Registration failed: ${response.body}');
    final body = _safeDecodeError(response.body);
    throw Exception(body);
  }

  /// Reads stored credentials — returns null if not logged in.
  Future<Map<String, dynamic>?> getStoredAuthData() async {
    try {
      final token = await _storage.read(key: _AuthKeys.jwt);
      final userId = await _storage.read(key: _AuthKeys.userId);
      final userDataJson = await _storage.read(key: _AuthKeys.userData);

      if (token == null || userId == null || userDataJson == null) return null;

      _logger.d('Stored auth data found for userId: $userId');
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

  /// Validates the stored JWT with the server.
  /// Clears credentials and returns false if invalid/expired.
  Future<bool> validateToken() async {
    try {
      final authData = await getStoredAuthData();
      if (authData == null) {
        _logger.d('No stored auth data for validation');
        return false;
      }

      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/auth/validate'),
            headers: {'Authorization': 'Bearer ${authData['token']}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Token valid → fire listeners so dependent services can init
        await _notifyListeners(authData['token'] as String);
        _logger.i('Token validation successful');
        return true;
      }

      _logger.w('Token invalid (${response.statusCode}), clearing credentials');
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
      }
      return false;
    } catch (e, st) {
      _logger.e('Token validation error', error: e, stackTrace: st);
      return false;
    }
  }

  /// Clear all stored credentials and notify the server.
  Future<void> logout() async {
    try {
      final token = await _storage.read(key: _AuthKeys.jwt);
      await Future.wait([
        _storage.delete(key: _AuthKeys.jwt),
        _storage.delete(key: _AuthKeys.userId),
        _storage.delete(key: _AuthKeys.userData),
      ]);
      _logger.i('Auth credentials cleared');

      if (token != null) {
        _notifyServerLogout(token); // fire-and-forget
      }
    } catch (e, st) {
      _logger.e('Logout error', error: e, stackTrace: st);
      // Still try to clear
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Persist JWT + user data and fire listeners.
  Future<void> _persist(Map<String, dynamic> responseData) async {
    final token = responseData['token'] as String;
    final userId = responseData['user']['_id'] as String;
    final userData = jsonEncode(responseData['user']);

    await Future.wait([
      _storage.write(key: _AuthKeys.jwt, value: token),
      _storage.write(key: _AuthKeys.userId, value: userId),
      _storage.write(key: _AuthKeys.userData, value: userData),
    ]);

    _logger.i('Auth data persisted for userId: $userId');
    await _notifyListeners(token);
  }

  Future<void> _notifyListeners(String jwt) async {
    for (final cb in _jwtListeners) {
      try {
        await cb(jwt);
      } catch (e) {
        _logger.w('JWT listener error (non-fatal): $e');
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
    } catch (_) {
      // Non-critical
    }
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
