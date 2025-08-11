import 'package:flutter/material.dart';
import 'package:momentum/pages/home_page.dart';
import 'package:momentum/pages/login_page.dart';
import 'package:momentum/pages/register_page.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // You can check for a stored JWT here to decide the initial route
        // For now, always show login first
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeProvider.themeData,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
            '/register': (context) => const RegisterPage(),
          },
        );
      },
    );
  }
}
