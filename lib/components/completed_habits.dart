import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/components/animated_habit_tile.dart';

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
    // Only show if there are completed habits for today
    if (completedHabits.isEmpty) {
      return const SizedBox.shrink();
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
            title: Text('Completed (${completedHabits.length})'),
            initiallyExpanded: showCompletedHabits,
            onExpansionChanged: onExpansionChanged,
            backgroundColor: Theme.of(context).colorScheme.surface,
            collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
            children: completedHabits.map((habit) {
              return AnimatedHabitTile(
                // Changed from HabitTile to AnimatedHabitTile
                key: ValueKey(habit.id), // Add key for proper widget updating
                isCompleted: true,
                text: habit.name,
                onChanged: (value) {
                  if (value != null) {
                    onChanged(habit)(value);
                  }
                },
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
