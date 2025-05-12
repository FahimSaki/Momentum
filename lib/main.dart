import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:habit_tracker/services/initialization_service.dart';

void main() async {
  await InitializationService.initialize();

  final habitDatabase = HabitDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitDatabase>.value(value: habitDatabase),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
