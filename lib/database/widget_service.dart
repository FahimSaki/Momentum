import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  static const String _androidWidget = 'MomentumHomeWidget';
  static const String _heatmapKey = 'heatmap_data';
  static const String _tasksKey = 'widget_tasks';

  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> tasks,
  ) async {
    if (kIsWeb) return;

    try {
      // ── Build heatmap data ─────────────────────────────────────────────────
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

      // Slide end-date to last active day if the current 35-day window is
      // entirely empty (avoids showing a blank heatmap for inactive recent days)
      DateTime endDate = DateTime.now();
      if (_buildHeatmapList(completionsByDate, endDate).every((v) => v == 0) &&
          completionsByDate.isNotEmpty) {
        final sorted = completionsByDate.keys.map((k) {
          final p = k.split('-');
          return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        }).toList()..sort();
        endDate = sorted.last;
      }

      final heatmapStr = _buildHeatmapList(
        completionsByDate,
        endDate,
      ).join(',');

      // ── Build task JSON ────────────────────────────────────────────────────
      // Use task.isArchived as the source of truth for completion state.
      // isCompletedToday() re-derives from completedDays locally which can be
      // stale; isArchived is set by the server and updated in completeTask().
      final activeTasks = tasks.where((t) => !t.isArchived).toList();
      final completedTasks = tasks.where((t) => t.isArchived).toList();

      // Active shown first, completed after, max 10 total
      final display = [...activeTasks, ...completedTasks].take(10);

      final taskJson = jsonEncode(
        display
            .map((t) => {'name': t.name, 'completed': t.isArchived})
            .toList(),
      );

      _logger.d('WidgetService — heatmap: $heatmapStr');
      _logger.d('WidgetService — tasks: $taskJson');

      // ── Write to SharedPreferences ─────────────────────────────────────────
      await HomeWidget.saveWidgetData<String>(_heatmapKey, heatmapStr);
      await HomeWidget.saveWidgetData<String>(_tasksKey, taskJson);

      // Brief pause to let SharedPreferences flush before the widget reads it
      await Future.delayed(const Duration(milliseconds: 150));

      // ── Trigger widget redraw ──────────────────────────────────────────────
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _androidWidget,
        qualifiedAndroidName: 'com.example.momentum.$_androidWidget',
      );

      _logger.i(
        'Widget updated — '
        '${activeTasks.length} active, ${completedTasks.length} completed, '
        '${completionsByDate.length} heatmap days total',
      );
    } catch (e, st) {
      _logger.e('WidgetService.updateWidget failed', error: e, stackTrace: st);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<int> _buildHeatmapList(Map<String, int> data, DateTime endDate) {
    return List.generate(35, (i) {
      final date = endDate.subtract(Duration(days: 34 - i));
      return data[_dateKey(date)] ?? 0;
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
