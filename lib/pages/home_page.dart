import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer.dart';
import 'package:habit_tracker/components/habit_tile.dart';
import 'package:habit_tracker/components/heat_map.dart';
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
  bool _showCompletedHabits = false;

  @override
  void initState() {
    super.initState();
    // Read existing habits from db
    Provider.of<HabitDatabase>(context, listen: false).readHabits();
    // Delete old completed habits
    Provider.of<HabitDatabase>(context, listen: false)
        .deleteOldCompletedHabits();
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
  void editHabitBox(Habit habit) {
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
  void deleteHabitBox(Habit habit) {
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
          _buildHeatMap(),

          // * H A B I T L I S T
          _buildHabitList(),
        ],
      ),
    );
  }

  // * build heat map
  Widget _buildHeatMap() {
    // habit database
    final habitDatabase = context.watch<HabitDatabase>();

    // current habits
    List<Habit> currentHabits = habitDatabase.currentHabits;

    // return heat map UI
    return FutureBuilder<DateTime?>(
      future: habitDatabase.getFirstLaunchDate(),
      builder: (context, snapshot) {
        // * once the first launch date is fetched build the heat map
        if (snapshot.hasData) {
          return MyHeatMap(
            startDate: snapshot.data!,
            datasets: prepareMapDatasets(currentHabits),
          );
        }
        // * handle case where empty data
        else {
          return Container();
        }
      },
    );
  }

  // * build habit list
  Widget _buildHabitList() {
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
              editHabit: (context) => editHabitBox(habit),
              deleteHabit: (context) => deleteHabitBox(habit),
            );
          },
        ),

        // * Completed habits dropdown
        const SizedBox(height: 10),
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                cardColor: Theme.of(context).colorScheme.surface,
              ),
              child: ExpansionTile(
                title: const Text('Completed Habits'),
                initiallyExpanded: _showCompletedHabits,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showCompletedHabits = expanded;
                  });
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                children: completedHabits.map((habit) {
                  return HabitTile(
                    isCompleted: true,
                    text: habit.name,
                    onChanged: (p0) => checkHabitOnOff(p0, habit),
                    editHabit: (context) => editHabitBox(habit),
                    deleteHabit: (context) => deleteHabitBox(habit),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
