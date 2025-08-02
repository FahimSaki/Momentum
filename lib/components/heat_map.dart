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
    final habitDatabase = context.watch<HabitDatabase>();
    final currentHabits = habitDatabase.currentHabits;

    return FutureBuilder<DateTime?>(
      future: habitDatabase.getFirstLaunchDate(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();

        final themeProvider = Provider.of<ThemeProvider>(context);
        final isLightMode = !themeProvider.isDarkMode;

        // Get BD time (UTC+6)
        final nowBD = DateTime.now().toUtc().add(const Duration(hours: 6));
        final today = DateTime(nowBD.year, nowBD.month, nowBD.day);

        final firstLaunchDate = snapshot.data!;
        final earliestAllowed = today.subtract(const Duration(days: 29));
        final startDate = firstLaunchDate.isBefore(earliestAllowed)
            ? earliestAllowed
            : firstLaunchDate;
        final endDate = today;

        return HeatMap(
          startDate: startDate,
          endDate: endDate,
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
      },
    );
  }
}
