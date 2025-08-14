import 'package:flutter/material.dart';
import 'package:momentum/pages/home_page.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/pages/splash_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeProvider.themeData,
          // 🔧 FIXED: Always start with splash screen for proper auth flow
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
            '/register': (context) => const RegisterPage(),
          },
          // 🔧 NEW: Handle unknown routes (like direct URL access to /home)
          onUnknownRoute: (settings) {
            // If someone tries to access any unknown route, redirect to splash
            print('Unknown route accessed: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => const SplashPage(),
            );
          },
          // 🔧 NEW: Better route generation for web support
          onGenerateRoute: (settings) {
            // Handle direct navigation to specific routes
            switch (settings.name) {
              case '/':
              case '/splash':
                return MaterialPageRoute(builder: (_) => const SplashPage());
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginPage());
              case '/register':
                return MaterialPageRoute(builder: (_) => const RegisterPage());
              case '/home':
                // 🔧 For direct /home access, go through splash for auth check
                return MaterialPageRoute(builder: (_) => const SplashPage());
              default:
                // Unknown route, redirect to splash
                return MaterialPageRoute(builder: (_) => const SplashPage());
            }
          },
        );
      },
    );
  }
}
