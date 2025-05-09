// given a habit list of completion days
// is habit completed today

import 'package:habit_tracker/models/habit.dart';

bool isHabitCompletedToday(List<DateTime> completionDays) {
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  return completionDays.any((date) {
    final completedDate = DateTime(date.year, date.month, date.day);
    return completedDate.isAtSameMoment(todayStart);
  });
}

// Helper extension
extension DateTimeComparison on DateTime {
  bool isAtSameMoment(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

bool shouldShowHabit(Habit habit) {
  if (habit.lastCompletedDate == null) return true;

  final today = DateTime.now();
  final lastCompleted = habit.lastCompletedDate!;

  return today.year != lastCompleted.year ||
      today.month != lastCompleted.month ||
      today.day != lastCompleted.day;
}

// * prepare datasets for heat map
Map<DateTime, int> prepareMapDatasets(List<Habit> habits) {
  Map<DateTime, int> datasets = {};

  for (var habit in habits) {
    for (var date in habit.completedDays) {
      // normalize date to avoid time mismatch
      final normalizedDate = DateTime(date.year, date.month, date.day);
      // if date is already in the map increment the count
      if (datasets.containsKey(normalizedDate)) {
        datasets[normalizedDate] = datasets[normalizedDate]! + 1;
      } else {
        // if date is not in the map add it with count 1
        datasets[normalizedDate] = 1;
      }
    }
  }
  return datasets;
}
