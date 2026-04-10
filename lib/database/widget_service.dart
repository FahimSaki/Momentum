import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  static const String _appGroupId = 'group.com.example.momentum';
  static const String _androidWidget = 'MomentumHomeWidget';
  static const String _heatmapKey = 'heatmap_data';
  static const String _tasksKey = 'widget_tasks';

  // ── Public API

  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> tasks,
  ) async {
    if (kIsWeb) return;

    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      // Build heatmap data
      final Map<String, int> completionsByDate = {};

      for (final task in tasks) {
        for (final d in task.completedDays) {
          final key = _dateKey(d.toLocal());
          completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
        }
      }
      for (final d in historicalCompletions) {
        final key = _dateKey(d.toLocal());
        completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
      }

      DateTime endDate = DateTime.now();

      // If the last 35 days are empty, slide the window to the last active day
      final recentData = _buildHeatmapList(completionsByDate, endDate);
      if (recentData.every((v) => v == 0) && completionsByDate.isNotEmpty) {
        final sorted = completionsByDate.keys.map((k) {
          final p = k.split('-');
          return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        }).toList()..sort();
        endDate = sorted.last;
      }

      // Build task JSON for the widget (active first, max 10 entries)
      final taskJson = _buildTaskJson(tasks);

      await _saveAndRefresh(completionsByDate, endDate, taskJson);
    } catch (e, st) {
      _logger.e('Error updating widget', error: e, stackTrace: st);
    }
  }

  // ── Helpers

  /// Produces a JSON array of up to 10 tasks: active ones first, then done.
  String _buildTaskJson(List<Task> tasks) {
    final active = tasks.where((t) => !t.isCompletedToday()).toList();
    final completed = tasks.where((t) => t.isCompletedToday()).toList();

    // Show active first, then completed, cap at 10 total
    final display = [...active, ...completed].take(10);

    final list = display
        .map((t) => {'name': t.name, 'completed': t.isCompletedToday()})
        .toList();

    return jsonEncode(list);
  }

  Future<void> _saveAndRefresh(
    Map<String, int> completionsByDate,
    DateTime endDate,
    String taskJson,
  ) async {
    final heatmapList = _buildHeatmapList(completionsByDate, endDate);
    final heatmapStr = heatmapList.join(',');

    _logger.d('Saving heatmap: $heatmapStr');
    _logger.d('Saving tasks: $taskJson');

    await HomeWidget.saveWidgetData<String>(_heatmapKey, heatmapStr);
    await HomeWidget.saveWidgetData<String>(_tasksKey, taskJson);

    // Short delay to let SharedPreferences flush
    await Future.delayed(const Duration(milliseconds: 120));

    await HomeWidget.updateWidget(
      name: _androidWidget,
      androidName: _androidWidget,
      iOSName: _androidWidget,
      qualifiedAndroidName: 'com.example.momentum.$_androidWidget',
    );

    _logger.i(
      'Widget refreshed — '
      '${heatmapList.where((v) => v > 0).length} active heatmap days, '
      '${taskJson.isNotEmpty ? "tasks saved" : "no tasks"}',
    );
  }

  List<int> _buildHeatmapList(Map<String, int> data, DateTime endDate) {
    return List.generate(35, (i) {
      final date = endDate.subtract(Duration(days: 34 - i));
      return data[_dateKey(date)] ?? 0;
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
