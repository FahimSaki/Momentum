/*

 S H O W   B O T H  C O M P L E T E D   A N D   I  N C O M P L E T E D   H A B I T S

 */

import 'package:flutter/material.dart';
import 'package:habit_tracker/components/animated_habit_tile.dart';
import 'package:habit_tracker/components/completed_habits.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:provider/provider.dart';

class HabitListComponent extends StatefulWidget {
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
  State<HabitListComponent> createState() => _HabitListComponentState();
}

class _HabitListComponentState extends State<HabitListComponent> {
  final Map<int, bool> _removedHabits = {};

  @override
  Widget build(BuildContext context) {
    final habitDatabase = context.watch<HabitDatabase>();
    List<Habit> currentHabits = habitDatabase.currentHabits;

    List<Habit> completedHabits = currentHabits
        .where((habit) => isHabitCompletedToday(habit.completedDays))
        .toList();
    List<Habit> uncompletedHabits = currentHabits
        .where((habit) => !isHabitCompletedToday(habit.completedDays))
        .toList();

    return Column(
      children: [
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
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _removedHabits[habit.id] == true
                    ? const SizedBox.shrink()
                    : AnimatedHabitTile(
                        key: ValueKey(habit.id),
                        isCompleted: false,
                        text: habit.name,
                        onChanged: (value) {
                          if (value == true) {
                            setState(() {
                              _removedHabits[habit.id] = true;
                            });
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              widget.checkHabitOnOff(value, habit);
                            });
                          } else {
                            widget.checkHabitOnOff(value, habit);
                          }
                        },
                        editHabit: (context) =>
                            widget.editHabitBox(context, habit),
                        deleteHabit: (context) =>
                            widget.deleteHabitBox(context, habit),
                      ),
              );
            },
          ),
        ],
        const SizedBox(height: 10),
        CompletedHabits(
          completedHabits: completedHabits,
          showCompletedHabits: widget.showCompletedHabits,
          onChanged: (habit) => (p0) => widget.checkHabitOnOff(p0, habit),
          editHabit: widget.editHabitBox,
          deleteHabit: widget.deleteHabitBox,
          onExpansionChanged: (expanded) {
            setState(() {});
          },
        ),
      ],
    );
  }
}
