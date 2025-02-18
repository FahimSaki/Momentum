import 'package:flutter/material.dart';
import 'package:habit_tracker/components/heat_map.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:provider/provider.dart';

class HeatMapComponent extends StatelessWidget {
  const HeatMapComponent({super.key});

  @override
  Widget build(BuildContext context) {
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
}
