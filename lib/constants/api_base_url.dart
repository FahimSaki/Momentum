import 'package:flutter/foundation.dart';

const String apiBaseUrl = kIsWeb
    ? 'https://momentum-to2e.onrender.com' // Web / production URL
    : (kReleaseMode
          ? 'https://momentum-to2e.onrender.com' // Mobile production URL
          : 'http://10.0.2.2:10000'); // Android emulator local URL

// Alternative debug configurations for different scenarios
const String localApiUrl = 'http://localhost:10000';
const String androidEmulatorUrl = 'http://10.0.2.2:10000';
const String iosSimulatorUrl = 'http://127.0.0.1:10000';
const String productionApiUrl = 'https://momentum-to2e.onrender.com';

// Enhanced URL selection with better debugging
String getApiBaseUrl() {
  if (kIsWeb) {
    return productionApiUrl;
  } else if (kDebugMode) {
    // For debugging, you can manually switch between these:
    return androidEmulatorUrl; // Change this for different test environments
    // return localApiUrl;
    // return iosSimulatorUrl;
  } else {
    return productionApiUrl;
  }
}

// Use this function instead of the constant if you need more flexibility
// In your services, replace apiBaseUrl with getApiBaseUrl()
