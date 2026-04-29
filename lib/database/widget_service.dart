import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  static const String _androidWidget = 'MomentumHomeWidget';
  static const String _tasksKey = 'widget_tasks';
  static const String _teamNameKey = 'widget_team_name';
  static const String _teamIdKey = 'widget_team_id';

  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> tasks, {
    Team? selectedTeam,
  }) async {
    if (kIsWeb) return;

    try {
      final teamName = selectedTeam?.name ?? 'Personal Tasks';
      final teamId = selectedTeam?.id ?? '';

      final activeTasks = tasks.where((t) => !t.isArchived).toList();
      final completedTasks = tasks.where((t) => t.isArchived).toList();
      final display = [...activeTasks, ...completedTasks].take(10);

      final taskList = display
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'completed': t.isArchived,
              'team': t.team?.name ?? '',
            },
          )
          .toList();

      final taskJson = jsonEncode(taskList);

      _logger.d('Widget update — team: $teamName, tasks: ${taskList.length}');

      // Save all keys before triggering the redraw.
      // home_widget v0.9 uses a single SharedPreferences file called
      // "HomeWidgetPreferences" — all keys must be written there.
      final results = await Future.wait([
        HomeWidget.saveWidgetData<String>(_tasksKey, taskJson),
        HomeWidget.saveWidgetData<String>(_teamNameKey, teamName),
        HomeWidget.saveWidgetData<String>(_teamIdKey, teamId),
      ]);

      // Check if saves succeeded
      final allSaved = results.every((r) => r == true);
      if (!allSaved) {
        _logger.w(
          'Some widget data saves returned false — widget may be stale',
        );
      }

      // Small flush delay, then trigger a redraw.
      await Future.delayed(const Duration(milliseconds: 300));

      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _androidWidget,
        qualifiedAndroidName: 'com.example.momentum.$_androidWidget',
      );

      _logger.i(
        'Widget updated — ${activeTasks.length} active, '
        '${completedTasks.length} completed, team=$teamName',
      );
    } catch (e, st) {
      // Widget updates are non-fatal — log and continue.
      _logger.e('Widget update failed', error: e, stackTrace: st);
      debugPrint('[WidgetService] Widget update failed: $e');
    }
  }
}
