import 'package:momentum/models/task.dart';

class TaskCompletionHelper {
  static bool isCompletedToday(Task task) {
    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);

    return task.completedDays.any((d) {
      final local = d.toLocal();
      final completedDay = DateTime(local.year, local.month, local.day);
      return completedDay.year == todayLocal.year &&
          completedDay.month == todayLocal.month &&
          completedDay.day == todayLocal.day;
    });
  }

  static Map<String, dynamic>? processCompletionToggle(
    Task task,
    bool isCompleted,
  ) {
    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);
    final todayUtc = todayLocal.toUtc();
    bool changed = false;

    if (isCompleted) {
      final alreadyToday = task.completedDays.any((d) {
        final local = d.toLocal();
        return local.year == todayLocal.year &&
            local.month == todayLocal.month &&
            local.day == todayLocal.day;
      });

      if (!alreadyToday) {
        task.completedDays.add(todayUtc);
        task.lastCompletedDate = todayUtc;
        task.isArchived = true;
        task.archivedAt = todayUtc;
        changed = true;
      }
    } else {
      final before = task.completedDays.length;
      task.completedDays.removeWhere((d) {
        final local = d.toLocal();
        return local.year == todayLocal.year &&
            local.month == todayLocal.month &&
            local.day == todayLocal.day;
      });

      if (before != task.completedDays.length) {
        task.isArchived = false;
        task.archivedAt = null;

        if (task.completedDays.isNotEmpty) {
          task.lastCompletedDate = task.completedDays.reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
        } else {
          task.lastCompletedDate = null;
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
