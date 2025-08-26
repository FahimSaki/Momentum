import 'package:flutter/material.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final Logger _logger = Logger();

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
      _logger.i('Stored auth data: $authData');

      if (!mounted) return;

      if (authData != null) {
        // Validate token with server
        final isValidToken = await AuthService.validateToken();
        _logger.i('Token validation result: $isValidToken');

        if (!mounted) return;

        if (isValidToken) {
          // Initialize TaskDatabase with stored credentials
          final taskDatabase =
              Provider.of<TaskDatabase>(context, listen: false);
          await taskDatabase.initialize(
            jwt: authData['token'],
            userId: authData['userId'],
          );
          _logger.i('TaskDatabase initialized successfully');

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _logger.w('Invalid token detected, logging out.');
          await AuthService.logout();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _logger.w('No stored auth data found.');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e, stackTrace) {
      _logger.e('Auth check error', error: e, stackTrace: stackTrace);
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
            Image.asset(
              isLightMode
                  ? 'assets/images/momentum_app_logo_main.png'
                  : 'assets/images/momentum_app_logo_main.png',
              width: 200,
              height: 163,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 163,
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
            Text(
              'Momentum',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
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
