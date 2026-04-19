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

      // Widget click handling (added)
      _setupWidgetListener();
      await _handleInitialWidgetLaunch();
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

  // Widget handling methods

  static void _setupWidgetListener() {
    HomeWidget.widgetClicked.listen((uri) {
      if (uri == null) return;

      final action = uri.queryParameters['widget_action'];
      final taskId = uri.queryParameters['task_id'];
      final teamId = uri.queryParameters['team_id'];

      debugPrint('Widget click: $action | task: $taskId | team: $teamId');

      switch (action) {
        case 'toggle_task':
          // TODO: toggle task
          break;

        case 'open_task':
          // TODO: navigate to task
          break;

        case 'add_task':
          // TODO: open add screen
          break;

        case 'refresh':
          // TODO: refresh widget data
          break;
      }
    });
  }

  static Future<void> _handleInitialWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();

    if (uri == null) return;

    final action = uri.queryParameters['widget_action'];
    final taskId = uri.queryParameters['task_id'];

    debugPrint('Cold start from widget: $action | task: $taskId');

    switch (action) {
      case 'toggle_task':
        // TODO: toggle task
        break;

      case 'open_task':
        // TODO: navigate to task
        break;

      case 'add_task':
        // TODO: open add screen
        break;

      case 'refresh':
        // TODO: refresh widget data
        break;
    }
  }
}
