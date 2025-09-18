import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, kReleaseMode;
import 'dart:io' show Platform;

const String apiBaseUrl = kIsWeb
    ? 'https://momentum-to2e.onrender.com' // Web
    : (kReleaseMode
          ? 'https://momentum-to2e.onrender.com' // Mobile production
          : 'http://10.0.2.2:10000'); // Android emulator

// Alternative debug configurations
String getApiBaseUrl() {
  if (kIsWeb) {
    return 'https://momentum-to2e.onrender.com';
  } else if (kDebugMode) {
    // For Android emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:10000'; // Android emulator
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:10000'; // iOS simulator
    } else {
      return 'http://localhost:10000'; // Other platforms
    }
  } else {
    return 'https://momentum-to2e.onrender.com'; // Production
  }
}
