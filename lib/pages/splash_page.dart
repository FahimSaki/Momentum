import 'package:flutter/material.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 1500));

      // Check if user has stored auth data
      final authData = await AuthService.getStoredAuthData();

      if (!mounted) return;

      if (authData != null) {
        // Validate token with server (optional but recommended)
        final isValidToken = await AuthService.validateToken();

        if (!mounted) return;

        if (isValidToken) {
          // Initialize TaskDatabase with stored credentials
          final taskDatabase =
              Provider.of<TaskDatabase>(context, listen: false);
          await taskDatabase.initialize(
            jwt: authData['token'],
            userId: authData['userId'],
          );

          if (!mounted) return;
          // Navigate to home page
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // Token is invalid, clear it and go to login
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // No stored auth data, go to login
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Auth check error: $e');
      // On error, go to login page
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              isLightMode
                  ? 'assets/images/momentum_app_logo_light.png'
                  : 'assets/images/momentum_app_logo_dark.png',
              width: 200,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image not found
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    size: 100,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // App Name
            Text(
              'Momentum',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Loading text
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .inversePrimary
                    .withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
