import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum/app.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:momentum/services/initialization_service.dart';
import 'package:momentum/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background handler BEFORE Firebase.initializeApp() — required
  // so the handler is available in the background isolate Flutter spins up.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Firebase BEFORE InitializationService so that returning users
  // (who have a saved JWT) can safely use FirebaseMessaging inside
  // InitializationService.initialize() without hitting an uninitialized app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init skipped or failed (non-fatal): $e');
  }

  await InitializationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskDatabase>(
          create: (context) => TaskDatabase(),
        ),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
