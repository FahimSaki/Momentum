import 'package:momentum/models/task.dart';

class TaskOrganizer {
  static void organizeTasks(
    List<Task> allTasks,
    List<Task> currentTasks,
    List<Task> activeTasks,
    List<Task> completedTasks,
  ) {
    final now = DateTime.now();
    final List<Task> active = [];
    final List<Task> completed = [];

    for (final task in allTasks) {
      if (!task.isArchived) {
        active.add(task);
      } else if (task.archivedAt != null &&
          now.difference(task.archivedAt!).inHours < 24) {
        completed.add(task);
      }
    }

    currentTasks
      ..clear()
      ..addAll([...active, ...completed]);

    activeTasks
      ..clear()
      ..addAll(active);

    completedTasks
      ..clear()
      ..addAll(completed);
  }
}
