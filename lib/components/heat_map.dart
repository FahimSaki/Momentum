import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:habit_tracker/database/task_database.dart';
import 'package:habit_tracker/models/task.dart';
import 'package:habit_tracker/util/task_util.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class HeatMapComponent extends StatelessWidget {
  const HeatMapComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final taskDatabase = context.watch<TaskDatabase>();
    List<Task> currentTasks = taskDatabase.currentTasks;

    return FutureBuilder<DateTime?>(
      future: Future.value(currentTasks.isNotEmpty
          ? currentTasks.first.createdAt
          : DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final isLightMode = !themeProvider.isDarkMode;

          return HeatMap(
            startDate: snapshot.data!,
            endDate: DateTime.now(),
            datasets: prepareMapDatasets(currentTasks),
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
        } else {
          return Container();
        }
      },
    );
  }
}
