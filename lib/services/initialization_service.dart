import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:momentum/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InitializationService {
  static final NotificationService _notificationService = NotificationService();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _appGroupId = 'group.com.example.momentum';

  /// Run this at app startup
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb) {
      // Set app group ID first — must happen before any widget read/write
      await HomeWidget.setAppGroupId(_appGroupId);

      final savedToken = await _secureStorage.read(key: 'jwt');
      if (savedToken != null) {
        await _notificationService.init(jwtToken: savedToken);
      }
    } else {
      await _notificationService.init(jwtToken: null);
    }
  }

  /// Save JWT after login
  static Future<void> saveJwt(String jwtToken) async {
    if (!kIsWeb) {
      await _secureStorage.write(key: 'jwt', value: jwtToken);
      await _notificationService.init(jwtToken: jwtToken);
    }
    // Web: rely on secure cookie set by backend
  }

  /// Clear JWT on logout
  static Future<void> clearJwt() async {
    if (!kIsWeb) {
      await _secureStorage.delete(key: 'jwt');
    }
    _notificationService.dispose();
  }
}
