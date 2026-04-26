import 'package:flutter/material.dart';
import 'package:momentum/pages/home_page.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/pages/splash_page.dart';
import 'package:momentum/services/initialization_service.dart';
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

          // Wired to InitializationService so widget-triggered navigation works
          // whether the app is cold-started or already in the foreground.
          navigatorKey: InitializationService.navigatorKey,

          initialRoute: '/splash',

          onGenerateRoute: (settings) {
            final name = settings.name;

            switch (name) {
              case '/':
              case '/splash':
                return MaterialPageRoute(builder: (_) => const SplashPage());

              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginPage());

              case '/register':
                return MaterialPageRoute(builder: (_) => const RegisterPage());

              case '/home':
                return MaterialPageRoute(builder: (_) => const HomePage());

              default:
                _logger.w('Unknown route accessed: $name');
                return MaterialPageRoute(builder: (_) => const SplashPage());
            }
          },

          onUnknownRoute: (settings) {
            _logger.w('onUnknownRoute triggered: ${settings.name}');
            return MaterialPageRoute(builder: (_) => const SplashPage());
          },
        );
      },
    );
  }
}
