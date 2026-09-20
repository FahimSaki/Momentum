import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:momentum/services/push_notification_service.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InitializationService {
  static final PushNotificationService _pushNotificationService =
      PushNotificationService();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _appGroupId = 'group.com.example.momentum';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static TaskCubit? _taskCubit;

  static String? _pendingAction;
  static String? _pendingTaskId;

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb) {
      await HomeWidget.setAppGroupId(_appGroupId);

      final savedToken = await _secureStorage.read(key: 'auth_jwt');
      if (savedToken != null) {
        await _pushNotificationService.init(jwtToken: savedToken);
      }

      _setupWidgetListener();
      await _handleInitialWidgetLaunch();
    }
  }

  /// Registers the current TaskCubit so widget-tap actions have
  /// something to act on.
  static void registerTaskCubit(TaskCubit cubit) {
    _taskCubit = cubit;
    if (_pendingAction != null) {
      final action = _pendingAction!;
      final taskId = _pendingTaskId;
      _pendingAction = null;
      _pendingTaskId = null;
      _handleWidgetAction(action, taskId);
    }
  }

  static Future<void> clearJwt() async {
    if (!kIsWeb) {
      await _secureStorage.delete(key: 'auth_jwt');
    }
    await _pushNotificationService.dispose();
  }

  static void _setupWidgetListener() {
    HomeWidget.widgetClicked.listen((uri) async {
      if (uri == null) return;
      debugPrint('[Widget] widgetClicked: $uri');
      final action = uri.queryParameters['widget_action'];
      final taskId = uri.queryParameters['task_id'];
      if (action != null) await _handleWidgetAction(action, taskId);
    });
  }

  static Future<void> _handleInitialWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri == null) return;
      debugPrint('[Widget] cold-start URI: $uri');
      final action = uri.queryParameters['widget_action'];
      final taskId = uri.queryParameters['task_id'];
      if (action != null) await _handleWidgetAction(action, taskId);
    } catch (e) {
      debugPrint('[Widget] initiallyLaunchedFromHomeWidget error: $e');
    }
  }

  static Future<void> _handleWidgetAction(String action, String? taskId) async {
    debugPrint('[Widget] action=$action taskId=$taskId');

    switch (action) {
      case 'complete_task':
      case 'toggle_task':
        if (taskId == null) break;

        if (_taskCubit == null) {
          _pendingAction = action;
          _pendingTaskId = taskId;
          break;
        }

        try {
          final matching = _taskCubit!.state.currentTasks
              .where((t) => t.id == taskId)
              .toList();
          if (matching.isNotEmpty) {
            final task = matching.first;
            final shouldComplete = !task.isCompletedToday();
            await _taskCubit!.completeTask(taskId, shouldComplete);
            await _taskCubit!.updateWidget();
          }
        } catch (e) {
          debugPrint('[Widget] completeTask error: $e');
        }
        break;

      case 'open_task':
        _navigateTo('/home');
        break;

      case 'edit_task':
        _navigateTo('/home');
        break;

      case 'add_task':
        _navigateTo('/home');
        break;

      case 'select_team':
        _navigateTo('/home');
        break;

      case 'refresh':
        if (_taskCubit == null) {
          _pendingAction = 'refresh';
          break;
        }
        try {
          await _taskCubit!.refreshData();
        } catch (e) {
          debugPrint('[Widget] refresh error: $e');
        }
        break;

      default:
        debugPrint('[Widget] unknown action: $action — opening home');
        _navigateTo('/home');
        break;
    }
  }

  static void _navigateTo(String route, {Object? arguments}) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(route, (r) => false, arguments: arguments);
    }
  }
}
