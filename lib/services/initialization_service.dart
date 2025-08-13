import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:momentum/services/notification_service.dart';

class SimpleInitializationService {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Only initialize notifications on mobile
    if (!kIsWeb) {
      await NotificationService().init();
    }
  }
}
