import 'package:momentum/models/task.dart';

class TaskOrganizer {
  static void organizeTasks(
    List<Task> allTasks,
    List<Task> currentTasks,
    List<Task> activeTasks,
    List<Task> completedTasks,
  ) {
    final List<Task> active = [];
    final List<Task> completed = [];

    for (final task in allTasks) {
      if (task.isCompletedToday()) {
        completed.add(task);
      } else {
        active.add(task);
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
