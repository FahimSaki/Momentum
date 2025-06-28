import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/database/task_database.dart';
import 'package:habit_tracker/theme/theme_provider.dart';

void main() {
  testWidgets('Task Tracker App Test', (WidgetTester tester) async {
    // Create test instances of your providers
    final taskDatabase = TaskDatabase();

    // Build our app and trigger a frame with required providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskDatabase>.value(value: taskDatabase),
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
