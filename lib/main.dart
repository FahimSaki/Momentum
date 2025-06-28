import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/database/task_database.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:habit_tracker/services/initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InitializationService.initialize();

  final taskDatabase = TaskDatabase();
  await taskDatabase.fetchTasks();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskDatabase>.value(value: taskDatabase),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
