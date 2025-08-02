import 'package:habit_tracker/models/habit.dart';

class HabitOrganizer {
  static void organizeHabits(
    List<Habit> allHabits,
    List<Habit> currentHabits,
    List<Habit> activeHabits,
    List<Habit> completedHabits,
  ) {
    final now = DateTime.now();
    final List<Habit> active = [];
    final List<Habit> completed = [];

    for (final habit in allHabits) {
      if (!habit.isArchived) {
        active.add(habit);
      } else if (habit.archivedAt != null &&
          now.difference(habit.archivedAt!).inHours < 24) {
        completed.add(habit);
      }
    }

    currentHabits
      ..clear()
      ..addAll([...active, ...completed]);

    activeHabits
      ..clear()
      ..addAll(active);

    completedHabits
      ..clear()
      ..addAll(completed);
  }
}
