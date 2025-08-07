import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer.dart';
import 'package:habit_tracker/components/heat_map.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/components/animated_habit_tile.dart';
import 'package:habit_tracker/components/completed_habits.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showCompletedHabits = false;
  final TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final db = Provider.of<HabitDatabase>(context, listen: false);
    db.readHabits();
    // 🔧 REMOVED: Don't call deleteCompletedHabits immediately!
    // The backend scheduler will handle cleanup automatically
  }

  void createNewHabit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Create a new habit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final newHabitName = textController.text.trim();
              if (newHabitName.isNotEmpty) {
                context.read<HabitDatabase>().addHabit(newHabitName);
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void editHabitBox(BuildContext context, Habit habit) {
    textController.text = habit.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                context
                    .read<HabitDatabase>()
                    .updateHabitName(habit.id, newName);
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void deleteHabitBox(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to delete this habit?'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<HabitDatabase>().deleteHabit(habit.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: const MyDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewHabit,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
      ),
      body: ListView(
        children: [
          const HeatMapComponent(),
          Consumer<HabitDatabase>(
            builder: (context, db, _) {
              final activeHabits = db.activeHabits;
              final completedHabits = db.completedHabits;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  ...activeHabits.map((habit) {
                    final isCompletedToday = habit.completedDays.any((d) {
                      final localDate = d.toLocal();
                      final now = DateTime.now();
                      return localDate.year == now.year &&
                          localDate.month == now.month &&
                          localDate.day == now.day;
                    });

                    return AnimatedHabitTile(
                      key: ValueKey(habit.id),
                      text: habit.name,
                      isCompleted: isCompletedToday,
                      onChanged: (value) {
                        context.read<HabitDatabase>().updateHabitCompletion(
                              habit.id,
                              value ?? false,
                            );
                      },
                      editHabit: (context) => editHabitBox(context, habit),
                      deleteHabit: (context) => deleteHabitBox(context, habit),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  CompletedHabits(
                    completedHabits: completedHabits,
                    showCompletedHabits: _showCompletedHabits,
                    onChanged: (habit) => (value) {
                      context
                          .read<HabitDatabase>()
                          .updateHabitCompletion(habit.id, value ?? false);
                    },
                    editHabit: editHabitBox,
                    deleteHabit: deleteHabitBox,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _showCompletedHabits = expanded;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
