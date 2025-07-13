import 'package:flutter/foundation.dart';

const String apiBaseUrl = kReleaseMode
    ? 'https://momentum-to2e.onrender.com' // Your Render production URL
    : 'http://10.0.2.2:10000'; // For Android emulator
