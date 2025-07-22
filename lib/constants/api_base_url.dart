import 'package:flutter/foundation.dart';

const String apiBaseUrl = kIsWeb
    ? 'https://momentum-to2e.onrender.com' // Web / production URL
    : (kReleaseMode
        ? 'https://momentum-to2e.onrender.com' // Mobile production URL
        : 'http://10.0.2.2:10000'); // Android emulator local URL
