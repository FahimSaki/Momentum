import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:momentum/config/api_base_url.dart';
import 'package:momentum/services/web_auth_redirect.dart'
    show getGoogleRedirectFragment, clearUrlFragment, navigateTo;

abstract class _AuthKeys {
  static const jwt = 'auth_jwt';
  static const userId = 'auth_user_id';
  static const userData = 'auth_user_data';
}

typedef JwtCallback = Future<void> Function(String jwt);

/// Result of checking the stored session against the server.
/// [valid] covers both a confirmed-good token AND "couldn't reach the
/// server to check" — in the latter case we keep the cached session and
/// let the rest of the app fall back to offline data rather than forcing
/// a login. Only an explicit 401/403 from the server produces
/// [requiresLogin].
enum TokenStatus { valid, requiresLogin }

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static final Logger _logger = Logger();

  // GOOGLE_CLIENT_ID from Firebase Console → Authentication → Google → Web client ID
  static const String _googleClientId =
      '213940967151-bju2m1cc7b7vnflibkb6hb6j0h2a1ug9.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // google_sign_in v7 made GoogleSignIn a singleton and requires an explicit
  // async initialize() call — exactly once — before any other method on the
  // instance is touched. This future is cached so every call site awaits
  // the same initialization instead of re-triggering it. Web no longer
  // touches GoogleSignIn.instance at all — see beginWebGoogleRedirect()
  // below — so this only matters for the mobile path now.
  Future<void>? _googleSignInInit;

  final List<JwtCallback> _jwtListeners = [];

  void onJwtAvailable(JwtCallback cb) => _jwtListeners.add(cb);

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize(
      clientId: kIsWeb ? _googleClientId : null,
      serverClientId: kIsWeb ? null : _googleClientId,
    );
  }

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
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
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
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 403 && data['requiresVerification'] == true) {
      return {'requiresVerification': true, 'email': data['email']};
    }

    if (response.statusCode == 200 && data['requiresTwoFactor'] == true) {
      return {'requiresTwoFactor': true, 'email': data['email']};
    }

    if (response.statusCode == 200 &&
        data['token'] != null &&
        (data['token'] as String).isNotEmpty) {
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
        .timeout(const Duration(seconds: 15));

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
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_safeDecodeError(response.body));
    }
  }

  // ── Forgot password ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim().toLowerCase()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_safeDecodeError(response.body));
  }

  // ── Reset password ───────────────────────────────────────────────────────────
  //
  // On success the backend behaves like login/verify2FA — it returns a
  // fresh token, since proving the emailed code + choosing a new password
  // is already a completed sign-in, and asking the user to type the
  // password they just set a second time would be redundant.

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/reset-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'code': code.trim(),
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 &&
        data['token'] != null &&
        (data['token'] as String).isNotEmpty) {
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    throw Exception(_safeDecodeError(response.body));
  }

  // ── Google Sign-In (mobile) ──────────────────────────────────────────────────
  //
  // On Android/iOS, GoogleSignIn.instance.authenticate() drives the native
  // picker and returns a real, signed GoogleSignInAccount (or throws).

  Future<Map<String, dynamic>> googleSignIn() async {
    await _ensureGoogleSignInInitialized();
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      return await _exchangeGoogleAccount(googleUser);
    } on GoogleSignInException catch (e, stackTrace) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google sign-in cancelled');
      }
      _logger.e('Google sign-in failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── Google Sign-In (web) ─────────────────────────────────────────────────────
  //
  // The GIS-rendered button (google_sign_in_web's renderButton) relies on a
  // popup relaying its result back to this page via postMessage. Confirmed
  // by reproduction: accounts.google.com's own strict Cross-Origin-Opener-
  // Policy blocks that relay regardless of what COOP value this page sends
  // — the popup completes and closes itself but the result never arrives.
  // A full-page redirect sidesteps the problem entirely: there's no popup
  // and no cross-window messaging involved at any point.

  /// Kicks off the redirect. Call from a button tap; this navigates away
  /// immediately, so there's nothing to await — the result is picked up by
  /// completeWebGoogleRedirect() on the next page load.
  void beginWebGoogleRedirect() {
    navigateTo(_buildGoogleRedirectUrl());
  }

  /// Cheap, synchronous check for whether the current URL is a return from
  /// beginWebGoogleRedirect() (i.e. it carries '#id_token=...' or
  /// '#error=...'). Check this before completeWebGoogleRedirect() so a
  /// normal page load doesn't show a loading state for no reason.
  bool hasWebGoogleRedirectResult() {
    if (!kIsWeb) return false;
    final fragment = getGoogleRedirectFragment();
    if (fragment == null || fragment.isEmpty) return false;
    return fragment.contains('id_token=') || fragment.contains('error=');
  }

  /// Reads and clears the redirect result, then exchanges the token with
  /// the backend exactly like the mobile flow does. Only call this after
  /// hasWebGoogleRedirectResult() returns true.
  Future<Map<String, dynamic>> completeWebGoogleRedirect() async {
    final fragment = getGoogleRedirectFragment();
    clearUrlFragment();

    if (fragment == null || fragment.isEmpty) {
      throw Exception('No sign-in result found');
    }

    final params = Uri.splitQueryString(fragment);

    final googleError = params['error'];
    if (googleError != null) {
      throw Exception(
        googleError == 'access_denied'
            ? 'Google sign-in cancelled'
            : 'Google sign-in failed: $googleError',
      );
    }

    final idToken = params['id_token'];
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return a sign-in token');
    }

    return _exchangeIdToken(idToken);
  }

  String _buildGoogleRedirectUrl() {
    final redirectUri = '${Uri.base.origin}/';
    final params = {
      'client_id': _googleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'id_token',
      'scope': 'openid email profile',
      'nonce': _generateNonce(),
      'prompt': 'select_account',
    };
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return 'https://accounts.google.com/o/oauth2/v2/auth?$query';
  }

  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ── Shared token exchange ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _exchangeIdToken(String idToken) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // The account may have 2FA enabled — same gate as password login. No
    // token yet in that case; the caller (googleSignIn /
    // completeWebGoogleRedirect) hands this straight back to the UI so it
    // can route to TwoFactorPage.
    if (response.statusCode == 200 && data['requiresTwoFactor'] == true) {
      return {'requiresTwoFactor': true, 'email': data['email']};
    }

    if (response.statusCode == 200 &&
        data['token'] != null &&
        (data['token'] as String).isNotEmpty) {
      await _persist(data);
      return {
        'token': data['token'],
        'userId': data['user']['_id'],
        'user': data['user'],
      };
    }

    throw Exception(_safeDecodeError(response.body));
  }

  Future<Map<String, dynamic>> _exchangeGoogleAccount(
    GoogleSignInAccount googleUser,
  ) async {
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');
    return _exchangeIdToken(idToken);
  }

  // ── Verify 2FA code ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> verify2FA(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/auth/verify-2fa'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 15));

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

      // A corrupted/undecryptable secure-storage entry can come back as an
      // empty string rather than null or a thrown error (seen on web when
      // the underlying encryption key changes between sessions). An empty
      // token used to pass the `!= null` check below, get handed to
      // TaskService, and produce header 'Authorization: Bearer ' on every
      // request — which the backend reads as an empty (falsy) token and
      // returns 401 "Access token required" instead of us cleanly
      // detecting "no usable session" and going to /login.
      if (token == null ||
          token.isEmpty ||
          userId == null ||
          userId.isEmpty ||
          userDataJson == null ||
          userDataJson.isEmpty) {
        return null;
      }

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

  /// Checks the stored token against the server. Returns
  /// [TokenStatus.requiresLogin] only when the server explicitly rejects
  /// the token (401/403) — everything else, including no connectivity at
  /// all, returns [TokenStatus.valid] so the session survives being
  /// offline. See [TokenStatus] for the reasoning.
  Future<TokenStatus> validateToken() async {
    final authData = await getStoredAuthData();
    if (authData == null) return TokenStatus.requiresLogin;

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/auth/validate'),
            headers: {'Authorization': 'Bearer ${authData['token']}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _notifyListeners(authData['token'] as String);
        return TokenStatus.valid;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return TokenStatus.requiresLogin;
      }

      // Any other status (5xx, etc.) isn't proof the token itself is bad —
      // don't sign the user out over a server hiccup.
      _logger.w('Unexpected /auth/validate status: ${response.statusCode}');
      return TokenStatus.valid;
    } catch (e, st) {
      // No connectivity, DNS failure, timeout, etc. — we simply can't ask
      // the server right now. Keep the existing session and let the rest
      // of the app fall back to cached data instead of forcing a login.
      _logger.w(
        'Token validation could not reach the server — assuming offline',
        error: e,
        stackTrace: st,
      );
      return TokenStatus.valid;
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
        await _ensureGoogleSignInInitialized();
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
