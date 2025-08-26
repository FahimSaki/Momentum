import 'package:momentum/models/task.dart';

class TaskCompletionHelper {
  static DateTime _getTodayUtc() {
    final localNow = DateTime.now();
    return DateTime(localNow.year, localNow.month, localNow.day).toUtc();
  }

  static bool isCompletedToday(Task task) {
    final today = _getTodayUtc();
    return task.completedDays.any(
      (d) =>
          d.toUtc().year == today.year &&
          d.toUtc().month == today.month &&
          d.toUtc().day == today.day,
    );
  }

  static Map<String, dynamic>? processCompletionToggle(
    Task task,
    bool isCompleted,
  ) {
    final today = _getTodayUtc();
    bool changed = false;

    if (isCompleted) {
      // Only add if today's date is not already present
      if (!task.completedDays.any(
        (d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day,
      )) {
        task.completedDays.add(today);
        task.lastCompletedDate = today;
        task.isArchived = true;
        task.archivedAt = today;
        changed = true;
      }
    } else {
      // Remove today's completion
      final before = task.completedDays.length;
      task.completedDays.removeWhere(
        (d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day,
      );

      if (before != task.completedDays.length) {
        final hasToday = task.completedDays.any(
          (d) =>
              d.toUtc().year == today.year &&
              d.toUtc().month == today.month &&
              d.toUtc().day == today.day,
        );
        if (!hasToday) {
          task.isArchived = false;
          task.archivedAt = null;

          if (task.completedDays.isNotEmpty) {
            task.lastCompletedDate = task.completedDays.reduce(
              (a, b) => a.isAfter(b) ? a : b,
            );
          } else {
            task.lastCompletedDate = null;
          }
        }
        changed = true;
      }
    }

    if (changed) {
      return {
        'completedDays': task.completedDays
            .map((e) => e.toIso8601String())
            .toList(),
        'lastCompletedDate': task.lastCompletedDate?.toIso8601String(),
        'isArchived': task.isArchived,
        'archivedAt': task.archivedAt?.toIso8601String(),
      };
    }

    return null;
  }
}
