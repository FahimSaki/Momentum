import 'package:habit_tracker/models/habit.dart';

class HabitCompletionHelper {
  static DateTime _getTodayUtc() {
    final localNow = DateTime.now();
    return DateTime(localNow.year, localNow.month, localNow.day).toUtc();
  }

  static bool isCompletedToday(Habit habit) {
    final today = _getTodayUtc();
    return habit.completedDays.any((d) =>
        d.toUtc().year == today.year &&
        d.toUtc().month == today.month &&
        d.toUtc().day == today.day);
  }

  static Map<String, dynamic>? processCompletionToggle(
      Habit habit, bool isCompleted) {
    final today = _getTodayUtc();
    bool changed = false;

    if (isCompleted) {
      // Only add if today's date is not already present
      if (!habit.completedDays.any((d) =>
          d.toUtc().year == today.year &&
          d.toUtc().month == today.month &&
          d.toUtc().day == today.day)) {
        habit.completedDays.add(today);
        habit.lastCompletedDate = today;
        habit.isArchived = true;
        habit.archivedAt = today;
        changed = true;
      }
    } else {
      // Remove today's completion
      final before = habit.completedDays.length;
      habit.completedDays.removeWhere((d) =>
          d.toUtc().year == today.year &&
          d.toUtc().month == today.month &&
          d.toUtc().day == today.day);

      if (before != habit.completedDays.length) {
        final hasToday = habit.completedDays.any((d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day);
        if (!hasToday) {
          habit.isArchived = false;
          habit.archivedAt = null;

          if (habit.completedDays.isNotEmpty) {
            habit.lastCompletedDate =
                habit.completedDays.reduce((a, b) => a.isAfter(b) ? a : b);
          } else {
            habit.lastCompletedDate = null;
          }
        }
        changed = true;
      }
    }

    if (changed) {
      return {
        'completedDays':
            habit.completedDays.map((e) => e.toIso8601String()).toList(),
        'lastCompletedDate': habit.lastCompletedDate?.toIso8601String(),
        'isArchived': habit.isArchived,
        'archivedAt': habit.archivedAt?.toIso8601String(),
      };
    }

    return null;
  }
}
