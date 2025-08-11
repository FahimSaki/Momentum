import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/util/task_util.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class HeatMapComponent extends StatelessWidget {
  const HeatMapComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final taskDatabase = context.watch<TaskDatabase>();
    final currentTasks = taskDatabase.currentTasks;
    final historicalCompletions = taskDatabase.historicalCompletions;

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate dynamically based on your data
    DateTime? earliestDataDate;
    if (historicalCompletions.isNotEmpty) {
      earliestDataDate =
          historicalCompletions.reduce((a, b) => a.isBefore(b) ? a : b);
    }

    // Use the earliest data date if available, otherwise use today (for new users)
    final firstLaunchDate = earliestDataDate ?? today;

    developer.log('Earliest data date: $earliestDataDate',
        name: 'HeatMapComponent');
    developer.log('Using first launch date: $firstLaunchDate',
        name: 'HeatMapComponent');

    // Calculate days since first launch
    final daysSinceFirstLaunch = today.difference(firstLaunchDate).inDays;
    developer.log('Days since first launch: $daysSinceFirstLaunch',
        name: 'HeatMapComponent');

    // Use progressive start date: grow from first launch until 39 days, then maintain 39-day window
    final startDate = daysSinceFirstLaunch < 39
        ? firstLaunchDate
        : today.subtract(const Duration(days: 39));

    developer.log('Start Date: $startDate', name: 'HeatMapComponent');

    final endDate = today;

    final datasets = prepareMapDatasets(currentTasks, historicalCompletions);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header outside the container
          Center(
            child: Text(
              'Activity Heatmap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Heatmap container
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Center(
              child: HeatMap(
                startDate: startDate,
                endDate: endDate,
                datasets: datasets,
                colorMode: ColorMode.color,
                defaultColor: Theme.of(context).colorScheme.secondary,
                textColor: isLightMode ? Colors.black87 : Colors.white70,
                showColorTip: false,
                showText: true,
                scrollable: false,
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
                margin: const EdgeInsets.all(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
