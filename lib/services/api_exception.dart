import 'dart:convert';
import 'package:http/http.dart' as http;

/// An error response from the backend. Carries the status code and the
/// message the server sent, so callers can show the real reason instead of
/// a generic "Failed to ...".
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  /// Builds an exception from a non-success [response]. Uses the body's
  /// `errors` (joined) or `message` when present, otherwise [fallback].
  factory ApiException.fromResponse(
    http.Response response, {
    required String fallback,
  }) {
    var message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        final serverMessage = data['message'];
        if (errors is List && errors.isNotEmpty) {
          message = errors.join(', ');
        } else if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      }
    } catch (_) {
      // Body was not JSON; keep the fallback.
    }
    return ApiException(response.statusCode, message);
  }

  /// The session is missing or deactivated (the backend answers 401).
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
