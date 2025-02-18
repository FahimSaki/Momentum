// given a habit list of completion days
// is habit completed today

import 'package:habit_tracker/models/habit.dart';

bool isHabitCompletedToday(List<DateTime> completionDays) {
  final today = DateTime.now();
  return completionDays.any(
    (date) =>
        date.day == today.day &&
        date.month == today.month &&
        date.year == today.year,
  );
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
