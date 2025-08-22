import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:momentum/models/task.dart';
import 'package:logger/logger.dart';

class WidgetService {
  final Logger _logger = Logger();

  Future<void> updateWidget(List<Task> tasks) async {
    if (kIsWeb) return;

    try {
      final List<String> widgetData = [];
      final now = DateTime.now();
      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        int completedCount = 0;
        for (final task in tasks) {
          if (task.completedDays.any((d) {
            final local = d.toLocal();
            return local.year == date.year &&
                local.month == date.month &&
                local.day == date.day;
          })) {
            completedCount++;
          }
        }
        widgetData.add(completedCount.toString());
      }
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
      List<DateTime> historicalCompletions, List<Task> currentTasks) async {
    if (kIsWeb) return;

    try {
      final List<String> widgetData = [];
      final now = DateTime.now();

      // Combine current task data with historical data
      final Set<DateTime> allCompletions = <DateTime>{};

      // Add current task completions
      for (final task in currentTasks) {
        allCompletions.addAll(task.completedDays);
      }

      // Add historical completions (from deleted tasks)
      allCompletions.addAll(historicalCompletions);

      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        int completedCount = 0;

        for (final completion in allCompletions) {
          final local = completion.toLocal();
          if (local.year == date.year &&
              local.month == date.month &&
              local.day == date.day) {
            completedCount++;
          }
        }
        widgetData.add(completedCount.toString());
      }

      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating widget with historical data',
          error: e, stackTrace: stackTrace);
    }
  }
}
