import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/utils/day_utils.dart';
import 'package:momentum/utils/role_helpers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tall enough that nothing in a form sits below the fold, so taps land.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Task _task({
  String name = 'Test Task',
  String priority = 'medium',
  String? description,
  List<DateTime> completedDays = const [],
  TaskSyncStatus syncStatus = TaskSyncStatus.synced,
}) => Task(
  id: '1',
  name: name,
  priority: priority,
  description: description,
  completedDays: completedDays,
  syncStatus: syncStatus,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget _tile(Task task, {Future<void> Function(bool)? onToggle}) =>
    ChangeNotifierProvider<ThemeProvider>.value(
      value: ThemeProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            onToggle: onToggle ?? (_) async {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginPage', () {
    testWidgets('shows the form and the alternative sign-in routes', (
      tester,
    ) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });
  });

  group('RegisterPage', () {
    testWidgets('shows the form', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Join Momentum'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('rejects empty fields before contacting the server', (
      tester,
    ) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('rejects a malformed email', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      await tester.enterText(find.byType(TextField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextField).at(1), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(2), 'secret1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('rejects a password shorter than six characters', (
      tester,
    ) async {
      _useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      await tester.enterText(find.byType(TextField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextField).at(1), 'jane@example.com');
      await tester.enterText(find.byType(TextField).at(2), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
    });
  });

  group('TaskTile', () {
    testWidgets('an active task shows its name, description and priority', (
      tester,
    ) async {
      await tester.pumpWidget(
        _tile(_task(description: 'Cover the model', priority: 'high')),
      );

      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('Cover the model'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('ticking the checkbox reports completion and flips the card', (
      tester,
    ) async {
      final task = _task();
      bool? received;

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => TaskTile(
                  task: task,
                  onToggle: (done) async {
                    received = done;
                    setState(() {
                      task.completedDays = done ? [localToday()] : [];
                    });
                  },
                  onEdit: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump();

      expect(received, isTrue);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('a task completed today shows the completed card', (
      tester,
    ) async {
      await tester.pumpWidget(_tile(_task(completedDays: [localToday()])));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('tapping a completed card asks to un-complete the task', (
      tester,
    ) async {
      bool? received;
      await tester.pumpWidget(
        _tile(
          _task(completedDays: [localToday()]),
          onToggle: (done) async {
            received = done;
          },
        ),
      );

      await tester.tap(find.text('Completed'));
      await tester.pump();

      expect(received, isFalse);
    });

    testWidgets('a task still waiting to sync shows the offline icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _tile(_task(syncStatus: TaskSyncStatus.pendingCreate)),
      );

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
    });

    testWidgets('a task the server rejected shows the sync-problem icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _tile(_task(syncStatus: TaskSyncStatus.syncFailed)),
      );

      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });
  });

  group('RoleBadge', () {
    testWidgets('shows the role in capitals', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RoleBadge(role: 'admin')),
        ),
      );

      expect(find.text('ADMIN'), findsOneWidget);
    });
  });
}
