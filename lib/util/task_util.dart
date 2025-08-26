import 'package:momentum/models/task.dart';

// Check if a task is completed today in BD time (UTC+6)
bool isTaskCompletedToday(List<DateTime> completionDays) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 6));
  final todayStart = DateTime(now.year, now.month, now.day);

  return completionDays.any((utcDate) {
    final local = utcDate.toUtc().add(const Duration(hours: 6));
    final completedDate = DateTime(local.year, local.month, local.day);
    return completedDate.isAtSameMoment(todayStart);
  });
}

// Helper extension for date-only comparison
extension DateTimeComparison on DateTime {
  bool isAtSameMoment(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

// Determine if a task should be shown (not completed today)
bool shouldShowTask(Task task) {
  if (task.lastCompletedDate == null) return true;

  final now = DateTime.now().toUtc().add(const Duration(hours: 6));
  final today = DateTime(now.year, now.month, now.day);

  final lastCompleted = task.lastCompletedDate!.toUtc().add(
    const Duration(hours: 6),
  );
  final completed = DateTime(
    lastCompleted.year,
    lastCompleted.month,
    lastCompleted.day,
  );

  return today != completed;
}

// 🔧 FIXED: Now accepts both current tasks AND historical completions
Map<DateTime, int> prepareMapDatasets(
  List<Task> tasks, [
  List<DateTime>? historicalCompletions,
]) {
  final Map<DateTime, int> heatMapData = {};

  // Process current tasks (same as before)
  for (final task in tasks) {
    for (final utcDate in task.completedDays) {
      final localDate = DateTime(
        utcDate.year,
        utcDate.month,
        utcDate.day,
      ).toLocal();
      final localMidnight = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );

      heatMapData.update(
        localMidnight,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  // 🔧 NEW: Process historical completions from deleted tasks
  if (historicalCompletions != null) {
    for (final utcDate in historicalCompletions) {
      final localDate = DateTime(
        utcDate.year,
        utcDate.month,
        utcDate.day,
      ).toLocal();
      final localMidnight = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );

      heatMapData.update(
        localMidnight,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  return heatMapData;
}
