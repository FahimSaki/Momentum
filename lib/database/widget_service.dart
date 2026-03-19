import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  Future<void> updateWidget(List<Task> tasks) async {
    if (kIsWeb) return;

    try {
      final now = DateTime.now();

      // Build completions map
      final Map<String, int> completionsByDate = {};
      for (final task in tasks) {
        for (final d in task.completedDays) {
          final local = d.toLocal();
          final key =
              '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
          completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
        }
      }

      final widgetData = _buildWidgetData(completionsByDate, now);

      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
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
      final now = DateTime.now();

      // Combine all completions
      final Set<DateTime> allCompletions = <DateTime>{};
      for (final task in tasks) {
        allCompletions.addAll(task.completedDays);
      }
      allCompletions.addAll(historicalCompletions);

      // Build completions map keyed by date string
      final Map<String, int> completionsByDate = {};
      for (final completion in allCompletions) {
        final local = completion.toLocal();
        final key =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        completionsByDate[key] = (completionsByDate[key] ?? 0) + 1;
      }

      // Try last 35 days ending today
      DateTime endDate = now;
      List<String> widgetData = _buildWidgetData(completionsByDate, endDate);

      // Fall back to last active period
      final bool allZeros = widgetData.every((v) => v == '0');
      if (allZeros && allCompletions.isNotEmpty) {
        final mostRecent = allCompletions
            .map((d) => d.toLocal())
            .reduce((a, b) => a.isAfter(b) ? a : b);

        endDate = DateTime(mostRecent.year, mostRecent.month, mostRecent.day);
        widgetData = _buildWidgetData(completionsByDate, endDate);
      }

      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating widget with historical data',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Builds 35 data points ending at endDate
  List<String> _buildWidgetData(
    Map<String, int> completionsByDate,
    DateTime endDate,
  ) {
    final List<String> widgetData = [];
    for (int i = 0; i < 35; i++) {
      final date = endDate.subtract(Duration(days: 34 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      widgetData.add((completionsByDate[key] ?? 0).toString());
    }
    return widgetData;
  }
}
