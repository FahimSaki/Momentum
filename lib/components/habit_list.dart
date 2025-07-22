import 'package:flutter/material.dart';
import 'package:habit_tracker/components/animated_habit_tile.dart';
import 'package:habit_tracker/components/completed_habits.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
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
  final Map<String, bool> _removedHabits = {};

  bool isCompletedToday(List<DateTime> completedDays) {
    final now = DateTime.now();
    return completedDays.any((d) {
      final local = d.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitDatabase = context.watch<HabitDatabase>();
    final currentHabits = habitDatabase.currentHabits;

    final uncompletedHabits = currentHabits.where((habit) {
      return !isCompletedToday(habit.completedDays) && !habit.isArchived;
    }).toList();

    final completedHabits = currentHabits.where((habit) {
      return isCompletedToday(habit.completedDays);
    }).toList();

    return Column(
      children: [
        if (uncompletedHabits.isEmpty && completedHabits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80, right: 16, left: 16),
            child: Text(
              'No tasks found. Please add a new task.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          )
        else
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
                        key: ValueKey('uncompleted_${habit.id}'),
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
        const SizedBox(height: 10),
        CompletedHabits(
          completedHabits: completedHabits,
          showCompletedHabits: widget.showCompletedHabits,
          onChanged: (habit) => (p0) {
            if (p0 == false) {
              setState(() {
                _removedHabits.remove(habit.id);
              });
            }
            widget.checkHabitOnOff(p0, habit);
          },
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
