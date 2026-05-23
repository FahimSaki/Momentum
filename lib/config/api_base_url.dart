import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;

const String _production = 'https://momentum-to2e.onrender.com';

/// Compile-time base URL. Use this for the vast majority of API calls.
const String apiBaseUrl = kIsWeb
    ? _production
    : (kReleaseMode ? _production : 'http://10.0.2.2:10000');

/// Runtime base URL — use only when you need to distinguish
/// Android from iOS in debug mode.
String resolvedApiBaseUrl() {
  if (kIsWeb || kReleaseMode) return _production;
  if (Platform.isIOS) return 'http://127.0.0.1:10000';
  return 'http://10.0.2.2:10000';
}
