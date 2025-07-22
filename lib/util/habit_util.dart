import 'package:habit_tracker/models/habit.dart';

// Check if a habit is completed today in BD time (UTC+6)
bool isHabitCompletedToday(List<DateTime> completionDays) {
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

// Determine if a habit should be shown (not completed today)
bool shouldShowHabit(Habit habit) {
  if (habit.lastCompletedDate == null) return true;

  final now = DateTime.now().toUtc().add(const Duration(hours: 6));
  final today = DateTime(now.year, now.month, now.day);

  final lastCompleted =
      habit.lastCompletedDate!.toUtc().add(const Duration(hours: 6));
  final completed =
      DateTime(lastCompleted.year, lastCompleted.month, lastCompleted.day);

  return today != completed;
}

// Prepare datasets for heat map with BD local time adjustment
Map<DateTime, int> prepareMapDatasets(List<Habit> habits) {
  final Map<DateTime, int> heatMapData = {};

  for (final habit in habits) {
    for (final utcDate in habit.completedDays) {
      final localDate =
          DateTime(utcDate.year, utcDate.month, utcDate.day).toLocal();
      final localMidnight =
          DateTime(localDate.year, localDate.month, localDate.day);

      heatMapData.update(localMidnight, (count) => count + 1,
          ifAbsent: () => 1);
    }
  }

  return heatMapData;
}
