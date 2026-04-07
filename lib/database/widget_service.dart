import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  // App Group ID - set this once at app start
  static const String _appGroupId = 'group.com.example.momentum';
  static const String _androidWidgetName = 'MomentumHomeWidget';
  static const String _heatmapKey = 'heatmap_data';

  Future<void> updateWidget(List<Task> tasks) async {
    if (kIsWeb) return;

    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      final Map<String, int> completionsByDate = {};
      for (final task in tasks) {
        for (final d in task.completedDays) {
          final local = d.toLocal();
          final key = _dateKey(local);
          completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
        }
      }

      await _saveAndUpdate(completionsByDate, DateTime.now());
    } catch (e, stackTrace) {
      _logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateWidgetWithHistoricalData(
    List<DateTime> historicalCompletions,
    List<Task> tasks,
  ) async {
    if (kIsWeb) return;

    try {
      final Map<String, int> completionsByDate = {};

      // Process current tasks
      for (final task in tasks) {
        for (final d in task.completedDays) {
          final local = d.toLocal();
          final key = _dateKey(local);
          completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
        }
      }

      // Process historical completions
      for (final d in historicalCompletions) {
        final local = d.toLocal();
        final key = _dateKey(local);
        completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
      }

      DateTime endDate = DateTime.now();

      // If no data for last 35 days, try to show the most recent active period
      final recentData = _buildWidgetData(completionsByDate, endDate);
      final allZeros = recentData.every((v) => v == 0);

      if (allZeros && completionsByDate.isNotEmpty) {
        // Find the most recent date with completions
        final allDates = completionsByDate.keys.map((k) {
          final parts = k.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }).toList()..sort();

        endDate = allDates.last;
      }

      await _saveAndUpdate(completionsByDate, endDate);
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating widget with historical data',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveAndUpdate(
    Map<String, int> completionsByDate,
    DateTime endDate,
  ) async {
    final widgetData = _buildWidgetData(completionsByDate, endDate);
    final dataString = widgetData.join(',');

    _logger.d('Saving widget data: $dataString');

    // Save the data first and AWAIT it fully before updating
    final saved = await HomeWidget.saveWidgetData<String>(
      _heatmapKey,
      dataString,
    );
    _logger.d('Widget data saved: $saved');

    // Small delay to ensure data is flushed to SharedPreferences
    await Future.delayed(const Duration(milliseconds: 100));

    // Now trigger the widget update
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
      iOSName: _androidWidgetName,
      qualifiedAndroidName: 'com.example.momentum.$_androidWidgetName',
    );

    _logger.i(
      'Widget updated with ${widgetData.where((v) => v > 0).length} active days',
    );
  }

  List<int> _buildWidgetData(
    Map<String, int> completionsByDate,
    DateTime endDate,
  ) {
    final List<int> widgetData = [];
    for (int i = 34; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      final key = _dateKey(date);
      widgetData.add(completionsByDate[key] ?? 0);
    }
    return widgetData;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
