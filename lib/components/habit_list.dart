/*

 S H O W   B O T H  C O M P L E T E D   A N D   I  N C O M P L E T E D   H A B I T S

 */

import 'package:flutter/material.dart';
import 'package:habit_tracker/components/habit_tile.dart';
import 'package:habit_tracker/components/completed_habits.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:provider/provider.dart';

class HabitListComponent extends StatelessWidget {
  final bool showCompletedHabits;
  final void Function(bool?, Habit) checkHabitOnOff;
  final void Function(BuildContext, Habit) editHabitBox;
  final void Function(BuildContext, Habit) deleteHabitBox;

  const HabitListComponent({
    super.key,
    required this.showCompletedHabits,
    required this.checkHabitOnOff,
    required this.editHabitBox,
    required this.deleteHabitBox,
  });

  @override
  Widget build(BuildContext context) {
    final habitDatabase = context.watch<HabitDatabase>();
    List<Habit> currentHabits = habitDatabase.currentHabits;

    // * Separate completed and uncompleted habits
    List<Habit> completedHabits = currentHabits
        .where((habit) => isHabitCompletedToday(habit.completedDays))
        .toList();
    List<Habit> uncompletedHabits = currentHabits
        .where((habit) => !isHabitCompletedToday(habit.completedDays))
        .toList();

    return Column(
      children: [
        // * Uncompleted habits
        if (uncompletedHabits.isEmpty && completedHabits.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 80, right: 16, left: 16),
            child: Text(
              'No habits found. Please add a new habit.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ] else ...[
          ListView.builder(
            itemCount: uncompletedHabits.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final habit = uncompletedHabits[index];
              return HabitTile(
                isCompleted: false,
                text: habit.name,
                onChanged: (p0) => checkHabitOnOff(p0, habit),
                editHabit: (context) => editHabitBox(context, habit),
                deleteHabit: (context) => deleteHabitBox(context, habit),
              );
            },
          ),
        ],

        // * Completed habits dropdown
        const SizedBox(height: 10),
        CompletedHabits(
          completedHabits: completedHabits,
          showCompletedHabits: showCompletedHabits,
          onChanged: (habit) => (p0) => checkHabitOnOff(p0, habit),
          editHabit: (context, habit) => editHabitBox(context, habit),
          deleteHabit: (context, habit) => deleteHabitBox(context, habit),
          onExpansionChanged: (expanded) {
            // Update the state in the parent widget
            (context as Element).markNeedsBuild();
          },
        ),
      ],
    );
  }
}
