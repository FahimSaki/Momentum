import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:momentum/services/notification_service.dart';
import 'package:momentum/database/task_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InitializationService {
  static final NotificationService _notificationService = NotificationService();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _appGroupId = 'group.com.example.momentum';

  // ── Public navigator key ─────────────────────────────────────────────────
  // Wire this into MaterialApp.navigatorKey in app.dart so widget-triggered
  // navigation works even when the app is in the foreground.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ── Private state ─────────────────────────────────────────────────────────
  static TaskDatabase? _taskDatabase;

  // If a widget action arrives before the DB is ready we queue it here.
  static String? _pendingAction;
  static String? _pendingTaskId;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Run at app startup (before runApp).
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb) {
      await HomeWidget.setAppGroupId(_appGroupId);

      final savedToken = await _secureStorage.read(key: 'jwt');
      if (savedToken != null) {
        await _notificationService.init(jwtToken: savedToken);
      }

      _setupWidgetListener();
      await _handleInitialWidgetLaunch();
    } else {
      await _notificationService.init(jwtToken: null);
    }
  }

  /// Call this once the TaskDatabase has been initialised (e.g. from
  /// HomePage.initState via a post-frame callback). Any queued widget action
  /// that arrived before the DB was ready will be replayed immediately.
  static void registerDatabase(TaskDatabase db) {
    _taskDatabase = db;
    if (_pendingAction != null) {
      final action = _pendingAction!;
      final taskId = _pendingTaskId;
      _pendingAction = null;
      _pendingTaskId = null;
      _handleWidgetAction(action, taskId);
    }
  }

  /// Save JWT after login so the notification service stays authenticated.
  static Future<void> saveJwt(String jwtToken) async {
    if (!kIsWeb) {
      await _secureStorage.write(key: 'jwt', value: jwtToken);
      await _notificationService.init(jwtToken: jwtToken);
    }
  }

  /// Clear JWT on logout.
  static Future<void> clearJwt() async {
    if (!kIsWeb) {
      await _secureStorage.delete(key: 'jwt');
    }
    _notificationService.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Listen for widget taps while the app is already running.
  static void _setupWidgetListener() {
    HomeWidget.widgetClicked.listen((uri) async {
      if (uri == null) return;
      debugPrint('[Widget] widgetClicked: $uri');
      final action = uri.queryParameters['widget_action'];
      final taskId = uri.queryParameters['task_id'];
      if (action != null) await _handleWidgetAction(action, taskId);
    });
  }

  /// Handle the URI if the app was cold-started by a widget tap.
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

  /// Central dispatcher for all widget actions.
  static Future<void> _handleWidgetAction(String action, String? taskId) async {
    debugPrint('[Widget] action=$action taskId=$taskId');

    switch (action) {
      // ── Task completion toggle ──────────────────────────────────────────
      case 'complete_task':
      case 'toggle_task':
        if (taskId == null) break;

        if (_taskDatabase == null) {
          // DB not ready yet — queue and replay after registerDatabase().
          _pendingAction = action;
          _pendingTaskId = taskId;
          break;
        }

        try {
          final matching = _taskDatabase!.currentTasks
              .where((t) => t.id == taskId)
              .toList();
          if (matching.isNotEmpty) {
            final task = matching.first;
            final shouldComplete = !task.isCompletedToday();
            await _taskDatabase!.completeTask(taskId, shouldComplete);
            // Refresh the widget immediately so the checkbox flips.
            await _taskDatabase!.updateWidget();
          }
        } catch (e) {
          debugPrint('[Widget] completeTask error: $e');
        }
        break;

      // ── Open a specific task ────────────────────────────────────────────
      case 'open_task':
        // Navigate to the Tasks tab (index 1) on the home page.
        _navigateTo('/home');
        break;

      // ── Edit a task ─────────────────────────────────────────────────────
      case 'edit_task':
        _navigateTo('/home');
        break;

      // ── Show task-creation dialog ───────────────────────────────────────
      case 'add_task':
        // Navigate home; the FAB is always visible for task creation.
        _navigateTo('/home');
        break;

      // ── Open team selector ──────────────────────────────────────────────
      case 'select_team':
        _navigateTo('/home');
        break;

      // ── Refresh widget data ─────────────────────────────────────────────
      case 'refresh':
        if (_taskDatabase == null) {
          _pendingAction = 'refresh';
          break;
        }
        try {
          await _taskDatabase!.refreshData();
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

  /// Navigate using the global key, removing all previous routes so the
  /// user lands cleanly on the target page.
  static void _navigateTo(String route, {Object? arguments}) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(route, (r) => false, arguments: arguments);
    }
  }
}
