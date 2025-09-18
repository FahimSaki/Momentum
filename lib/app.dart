import 'package:flutter/material.dart';
import 'package:momentum/pages/home_page.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/pages/splash_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeProvider.themeData,
          //  FIXED: Always start with splash screen for proper auth flow
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
            '/register': (context) => const RegisterPage(),
          },
          // Handle unknown routes (like direct URL access to /home)
          onUnknownRoute: (settings) {
            // If someone tries to access any unknown route, redirect to splash
            _logger.w('Unknown route accessed: ${settings.name}');
            return MaterialPageRoute(builder: (context) => const SplashPage());
          },
          // Better route generation for web support
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
                return MaterialPageRoute(builder: (_) => const SplashPage());
              default:
                return MaterialPageRoute(builder: (_) => const SplashPage());
            }
          },
        );
      },
    );
  }
}
