import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

      // Write all three keys before triggering the redraw
      await HomeWidget.saveWidgetData<String>(_tasksKey, taskJson);
      await HomeWidget.saveWidgetData<String>(_teamNameKey, teamName);
      await HomeWidget.saveWidgetData<String>(_teamIdKey, teamId);

      // Small flush delay then redraw
      await Future.delayed(const Duration(milliseconds: 200));

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
      _logger.e('Widget update failed', error: e, stackTrace: st);
    }
  }
}
