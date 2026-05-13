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

  // ── IMPORTANT: Register background handler BEFORE Firebase.initializeApp
  // This must happen before any Firebase call so the handler is registered
  // in the background isolate that Flutter spins up for terminated-state FCM.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await InitializationService.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init skipped or failed (non-fatal): $e');
  }

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
