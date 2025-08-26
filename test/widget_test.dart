import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Setup shared preferences mock for all tests
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Isolated Widget Tests', () {
    testWidgets('Login page renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
      expect(find.text('Login'), findsOneWidget);
      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });

    testWidgets('Register page renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
      expect(find.text('Register'), findsOneWidget);
      expect(find.text("Already have an account? Login"), findsOneWidget);
    });

    testWidgets('Task tile displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(home: Scaffold(body: _TestableTaskTile())),
        ),
      );

      // Verify initial text + checkbox
      expect(find.text('Test Task'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap the checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Now it should be checked
      final Checkbox checkbox = tester.widget(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('Text input validation', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Test Input',
                hintText: 'Enter text',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Input'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.pump();

      expect(controller.text, equals('Hello World'));
    });

    testWidgets('Elevated button works', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {
                buttonPressed = true;
              },
              child: const Text('Test Button'),
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(buttonPressed, isTrue);
    });
  });

  group('Theme Tests', () {
    testWidgets('Theme provider can be created', (WidgetTester tester) async {
      // Create theme provider without SharedPreferences complications
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: Consumer<ThemeProvider>(
            builder: (context, provider, child) {
              return MaterialApp(
                theme: provider.themeData,
                home: const Scaffold(body: Text('Theme Test')),
              );
            },
          ),
        ),
      );

      expect(find.text('Theme Test'), findsOneWidget);
    });
  });

  group('Component Tests', () {
    testWidgets('Basic container styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Styled Container'),
            ),
          ),
        ),
      );

      expect(find.text('Styled Container'), findsOneWidget);

      final Container container = tester.widget(find.byType(Container));
      expect(container.padding, equals(const EdgeInsets.all(16)));
    });

    testWidgets('List tile renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: const Text('Test Title'),
              subtitle: const Text('Test Subtitle'),
              leading: const Icon(Icons.star),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });
}

/// Helper widget for testing TaskTile with state
class _TestableTaskTile extends StatefulWidget {
  @override
  State<_TestableTaskTile> createState() => _TestableTaskTileState();
}

class _TestableTaskTileState extends State<_TestableTaskTile> {
  bool taskCompleted = false;

  @override
  Widget build(BuildContext context) {
    return TaskTile(
      text: 'Test Task',
      isCompleted: taskCompleted,
      onChanged: (value) {
        setState(() {
          taskCompleted = value ?? false;
        });
      },
      editTask: (context) {},
      deleteTask: (context) {},
    );
  }
}
