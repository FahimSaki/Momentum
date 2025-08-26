import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum/app.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/services/initialization_service.dart';

void main() async {
  await InitializationService.initialize();

  // Create TaskDatabase instance
  final taskDatabase = TaskDatabase();

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
