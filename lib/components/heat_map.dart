import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
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
          final themeProvider = Provider.of<ThemeProvider>(context);
          final isLightMode = !themeProvider.isDarkMode;

          return HeatMap(
            startDate: snapshot.data!,
            endDate: DateTime.now(),
            datasets: prepareMapDatasets(currentHabits),
            colorMode: ColorMode.color,
            defaultColor: Theme.of(context).colorScheme.secondary,
            textColor: Colors.white,
            showColorTip: false,
            showText: true,
            scrollable: true,
            size: 30,
            colorsets: isLightMode
                ? {
                    1: Colors.green.shade200,
                    2: Colors.green.shade300,
                    3: Colors.green.shade400,
                    4: Colors.green.shade500,
                    5: Colors.green.shade600,
                  }
                : {
                    1: Colors.teal.shade200,
                    2: Colors.teal.shade300,
                    3: Colors.teal.shade400,
                    4: Colors.teal.shade500,
                    5: Colors.teal.shade600,
                  },
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
