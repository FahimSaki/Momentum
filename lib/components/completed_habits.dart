import 'package:flutter/material.dart';
import 'package:habit_tracker/components/habit_tile.dart';
import 'package:habit_tracker/models/habit.dart';

class CompletedHabits extends StatelessWidget {
  final List<Habit> completedHabits;
  final bool showCompletedHabits;
  final ValueChanged<bool?> Function(Habit) onChanged;
  final void Function(BuildContext, Habit) editHabit;
  final void Function(BuildContext, Habit) deleteHabit;
  final ValueChanged<bool> onExpansionChanged;

  const CompletedHabits({
    super.key,
    required this.completedHabits,
    required this.showCompletedHabits,
    required this.onChanged,
    required this.editHabit,
    required this.deleteHabit,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the completed habits list is empty
    if (completedHabits.isEmpty) {
      return Container(); // Return an empty container if the list is empty
    }

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            cardColor: Theme.of(context).colorScheme.surface,
          ),
          child: ExpansionTile(
            title: const Text('Completed'),
            initiallyExpanded: showCompletedHabits,
            onExpansionChanged: onExpansionChanged,
            backgroundColor: Theme.of(context).colorScheme.surface,
            collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
            children: completedHabits.map((habit) {
              return HabitTile(
                isCompleted: true,
                text: habit.name,
                onChanged: onChanged(habit),
                editHabit: (context) => editHabit(context, habit),
                deleteHabit: (context) => deleteHabit(context, habit),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
