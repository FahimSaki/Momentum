import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/util/habit_util.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class HeatMapComponent extends StatelessWidget {
  const HeatMapComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final habitDatabase = context.watch<HabitDatabase>();
    final currentHabits = habitDatabase.currentHabits;
    final historicalCompletions = habitDatabase.historicalCompletions;

    return FutureBuilder<DateTime?>(
      future: habitDatabase.getFirstLaunchDate(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();

        final themeProvider = Provider.of<ThemeProvider>(context);
        final isLightMode = !themeProvider.isDarkMode;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // 🔧 FIXED: Always show a full range regardless of first launch date
        final startDate =
            today.subtract(const Duration(days: 89)); // Show last 90 days
        final endDate = today;

        // 🔧 DEBUG: Log the date range
        print(
            '🔍 Heatmap date range: ${startDate.toString()} to ${endDate.toString()}');
        print('🔍 Current habits: ${currentHabits.length}');
        print('🔍 Historical completions: ${historicalCompletions.length}');

        final datasets =
            prepareMapDatasets(currentHabits, historicalCompletions);
        print('🔍 Total dataset entries: ${datasets.length}');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date range info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Heatmap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Heatmap
                Expanded(
                  child: HeatMap(
                    startDate: startDate,
                    endDate: endDate,
                    datasets: datasets,
                    colorMode: ColorMode.color,
                    defaultColor: Theme.of(context).colorScheme.secondary,
                    textColor: isLightMode ? Colors.black87 : Colors.white70,
                    showColorTip: false,
                    showText: true,
                    scrollable: true,
                    size: 28,
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
                    margin: const EdgeInsets.all(2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
