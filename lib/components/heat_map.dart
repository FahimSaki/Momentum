import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MyHeatMap extends StatelessWidget {
  final DateTime startDate;
  final Map<DateTime, int> datasets;

  const MyHeatMap({
    super.key,
    required this.startDate,
    required this.datasets,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return HeatMap(
      startDate: startDate,
      endDate: DateTime.now(),
      datasets: datasets,
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
}
