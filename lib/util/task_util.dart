import 'package:momentum/models/task.dart';

// Check if a task is completed today in local time
bool isTaskCompletedToday(List<DateTime> completionDays) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  return completionDays.any((date) {
    final local = date.toLocal();
    final completedDate = DateTime(local.year, local.month, local.day);
    return completedDate.isAtSameMomentAs(todayStart);
  });
}

// Helper extension for date-only comparison
extension DateTimeComparison on DateTime {
  bool isAtSameMomentAs(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

// Determine if a task should be shown (not completed today)
bool shouldShowTask(Task task) {
  if (task.lastCompletedDate == null) return true;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final lastCompleted = task.lastCompletedDate!.toLocal();
  final completed = DateTime(
    lastCompleted.year,
    lastCompleted.month,
    lastCompleted.day,
  );

  return !today.isAtSameMomentAs(completed);
}

// FIXED: Proper date filtering and map preparation
Map<DateTime, int> prepareMapDatasets(
  List<Task> tasks, [
  List<DateTime>? historicalCompletions,
]) {
  final Map<DateTime, int> heatMapData = {};

  // Process current tasks
  for (final task in tasks) {
    for (final utcDate in task.completedDays) {
      final localDate = utcDate.toLocal();
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

  // Process historical completions from deleted tasks
  if (historicalCompletions != null) {
    for (final utcDate in historicalCompletions) {
      final localDate = utcDate.toLocal();
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

// Safe date filtering helper
List<DateTime> filterDatesByRange(
  List<DateTime> dates,
  DateTime startDate,
  DateTime endDate,
) {
  return dates.where((date) {
    final localDate = date.toLocal();
    final dayOnly = DateTime(localDate.year, localDate.month, localDate.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    return (dayOnly.isAfter(startDay) || dayOnly.isAtSameMomentAs(startDay)) &&
        (dayOnly.isBefore(endDay) || dayOnly.isAtSameMomentAs(endDay));
  }).toList();
}

// Safe completion counting
int countCompletionsInRange(
  List<Task> tasks,
  DateTime startDate,
  DateTime endDate,
) {
  int count = 0;

  for (final task in tasks) {
    final filteredDays = filterDatesByRange(
      task.completedDays,
      startDate,
      endDate,
    );
    count += filteredDays.length;
  }

  return count;
}
