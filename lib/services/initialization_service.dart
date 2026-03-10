import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:momentum/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InitializationService {
  static final NotificationService _notificationService = NotificationService();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Run this at app startup
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb) {
      // Mobile → restore JWT from secure storage
      final savedToken = await _secureStorage.read(key: 'jwt');
      if (savedToken != null) {
        await _notificationService.init(jwtToken: savedToken);
      }
    } else {
      // Web → JWT is handled by httpOnly cookie automatically
      // Just initialize without token here
      await _notificationService.init(jwtToken: null);
    }
  }

  /// Save JWT after login
  static Future<void> saveJwt(String jwtToken) async {
    if (!kIsWeb) {
      // Mobile → persist securely
      await _secureStorage.write(key: 'jwt', value: jwtToken);
      await _notificationService.init(jwtToken: jwtToken);
    } else {
      // Web → rely on secure cookie set by backend
    }
  }

  /// Clear JWT on logout
  static Future<void> clearJwt() async {
    if (!kIsWeb) {
      await _secureStorage.delete(key: 'jwt');
    }
    _notificationService.dispose();
  }
}
