import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer.dart';
import 'package:habit_tracker/components/habit_tile.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    // read existing habits from db
    Provider.of<HabitDatabase>(context, listen: false).readHabits();
    super.initState();
  }

  // text controller
  final TextEditingController textController = TextEditingController();

  // create a new habit
  void createNewHabit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'create a new habit',
            hintStyle: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        actions: [
          // save button
          MaterialButton(
            onPressed: () {
              // get the new habit name
              String newHabitName = textController.text;

              // save to db
              context.read<HabitDatabase>().addHabit(newHabitName);

              // pop box
              Navigator.pop(context);

              // clear controller
              textController.clear();
            },
            child: const Text('Save'),
          ),

          // cancel button
          MaterialButton(
            onPressed: () {
              // pop box
              Navigator.pop(context);

              // clear controller
              textController.clear();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // check habit on off
  void checkHabitOnOff(bool? p0, Habit habit) {
    // check if habit is completed today
    if (p0 != null) {
      // add today to completed days
      context.read<HabitDatabase>().updateHabitCompletion(habit.id, p0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
      ),
      drawer: const MyDrawer(),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        onPressed: createNewHabit,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
      ),
      body: _buildHabitList(),
    );
  }

// build habit list
  Widget _buildHabitList() {
    // habit db
    final habitDatabase = context.watch<HabitDatabase>();

    // current habits
    List<Habit> currentHabits = habitDatabase.currentHabits;

    // return list of habits UI
    return ListView.builder(
      itemBuilder: (context, index) {
        // get each individual habit
        final habit = currentHabits[index];

        // check if the habit is completed today
        bool isCompletedtToday = isHabitCompletedToday(habit.completedDays);

        // return habit tile UI
        return HabitTile(
          isCompleted: isCompletedtToday,
          text: habit.name,
          onChanged: (p0) => checkHabitOnOff(p0, habit),
        );
      },
    );
  }
}
