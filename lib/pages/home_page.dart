import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer.dart';
import 'package:habit_tracker/components/heat_map.dart';
import 'package:habit_tracker/components/habit_list.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/models/habit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final bool _showCompletedHabits = false;

  @override
  void initState() {
    super.initState();
    // Read existing habits from db
    Provider.of<HabitDatabase>(context, listen: false).readHabits();
    // Delete old completed habits
    Provider.of<HabitDatabase>(context, listen: false).deleteCompletedHabits();
  }

  // text controller
  final TextEditingController textController = TextEditingController();

  // * create a new habit
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

  // * check habit on off
  void checkHabitOnOff(bool? p0, Habit habit) {
    // check if habit is completed today
    if (p0 != null) {
      // add today to completed days
      context.read<HabitDatabase>().updateHabitCompletion(habit.id, p0);
    }
  }

  // * edit habit box
  void editHabitBox(BuildContext context, Habit habit) {
    // set the controller text to the habit name
    textController.text = habit.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
        ),
        actions: [
          // save button
          MaterialButton(
            onPressed: () {
              // get the new habit name
              String newHabitName = textController.text;

              // save to db
              context
                  .read<HabitDatabase>()
                  .updateHabitName(habit.id, newHabitName);

              // pop box
              Navigator.pop(context);

              // clear controller
              textController.clear();
            },
            child: const Text('Save'),
          ),
          // cancel button
        ],
      ),
    );
  }

  // * delete habit box
  void deleteHabitBox(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to delete this habit?'),
        actions: [
          // delete button
          MaterialButton(
            onPressed: () {
              // delete habit
              context.read<HabitDatabase>().deleteHabit(habit.id);

              // pop box
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),

          // cancel button
          MaterialButton(
            onPressed: () {
              // pop box
              Navigator.pop(context);
            },
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
        elevation: 0,
        onPressed: createNewHabit,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
      ),
      body: ListView(
        children: [
          // * H E A T M A P
          const HeatMapComponent(),

          // * H A B I T L I S T
          HabitListComponent(
            showCompletedHabits: _showCompletedHabits,
            checkHabitOnOff: checkHabitOnOff,
            editHabitBox: editHabitBox,
            deleteHabitBox: deleteHabitBox,
          ),
        ],
      ),
    );
  }
}
