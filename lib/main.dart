import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:habit_tracker/services/initialization_service.dart';
import 'package:habit_tracker/services/realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await InitializationService.initialize();

  final realtimeService = RealtimeService();
  await realtimeService.init();

  final habitDatabase = HabitDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitDatabase>.value(value: habitDatabase),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        Provider<RealtimeService>.value(
            value: realtimeService), // Add this line
      ],
      child: const MyApp(),
    ),
  );
}
