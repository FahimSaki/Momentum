import 'package:flutter/material.dart';
import 'package:habit_tracker/database/habit_database.dart';
import 'package:habit_tracker/pages/home_page.dart';
import 'package:habit_tracker/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:habit_tracker/services/realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables first
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize HabitDatabase statically first
  await HabitDatabase.init();

  // Create instance after initialization
  final habitDatabase = HabitDatabase();

  // Initialize RealtimeService
  await RealtimeService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitDatabase>.value(
          value: habitDatabase, // Use the initialized instance
        ),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const HomePage(),
          theme: themeProvider.themeData,
        );
      },
    );
  }
}
