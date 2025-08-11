import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum/app.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/services/initialization_service.dart';
import 'package:momentum/services/realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InitializationService.initialize();

  final realtimeService = RealtimeService();

  // Don't call readTasks() here because JWT and userId are not set yet
  final taskDatabase = TaskDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskDatabase>.value(value: taskDatabase),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        Provider<RealtimeService>.value(value: realtimeService),
      ],
      child: const MyApp(),
    ),
  );
}
