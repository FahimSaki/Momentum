import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:momentum/app.dart';
import 'package:momentum/blocs/notification_cubit.dart';
import 'package:momentum/blocs/session_cubit.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/blocs/team_cubit.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/services/initialization_service.dart';
import 'package:momentum/services/push_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init skipped or failed (non-fatal): $e');
  }

  await InitializationService.initialize();

  // TaskCubit takes the other three as constructor references and
  // listens to teamCubit.stream for selection changes.
  final notificationCubit = NotificationCubit();
  final teamCubit = TeamCubit();
  final sessionCubit = SessionCubit();
  final taskCubit = TaskCubit(
    notificationCubit: notificationCubit,
    teamCubit: teamCubit,
    sessionCubit: sessionCubit,
  );

  runApp(
    MultiProvider(
      providers: [
        BlocProvider<NotificationCubit>.value(value: notificationCubit),
        BlocProvider<TeamCubit>.value(value: teamCubit),
        BlocProvider<SessionCubit>.value(value: sessionCubit),
        BlocProvider<TaskCubit>.value(value: taskCubit),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
