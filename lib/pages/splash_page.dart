import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  String? _googleRedirectError;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // If we've just been redirected back from Google (web only), finish
      // that sign-in first — it takes priority over any stored session,
      // and the URL fragment needs to be read and cleared exactly once,
      // here, before the normal stored-token check below runs.
      if (kIsWeb && AuthService.instance.hasWebGoogleRedirectResult()) {
        try {
          final result = await AuthService.instance.completeWebGoogleRedirect();
          if (!mounted) return;
          final taskDatabase = Provider.of<TaskDatabase>(
            context,
            listen: false,
          );
          await taskDatabase.initialize(
            jwt: result['token'] as String,
            userId: result['userId'] as String,
          );
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
          return;
        } catch (e, stackTrace) {
          _logger.e(
            'Google redirect sign-in failed',
            error: e,
            stackTrace: stackTrace,
          );
          if (!mounted) return;
          final msg = e.toString().replaceFirst('Exception: ', '');
          if (msg.contains('cancelled')) {
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            setState(() => _googleRedirectError = msg);
          }
          return;
        }
      }

      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 1500));

      // Check if user has stored auth data
      final authData = await AuthService.instance.getStoredAuthData();
      _logger.i('Stored auth data: $authData');

      if (!mounted) return;

      if (authData != null) {
        // Validate token with server
        final isValidToken = await AuthService.instance.validateToken();
        _logger.i('Token validation result: $isValidToken');

        if (!mounted) return;

        if (isValidToken) {
          // Initialize TaskDatabase with stored credentials
          final taskDatabase = Provider.of<TaskDatabase>(
            context,
            listen: false,
          );
          await taskDatabase.initialize(
            jwt: authData['token'],
            userId: authData['userId'],
          );
          _logger.i('TaskDatabase initialized successfully');

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _logger.w('Invalid token detected, logging out.');
          await AuthService.instance.logout();
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
            if (_googleRedirectError == null) ...[
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
                  color: Theme.of(
                    context,
                  ).colorScheme.inversePrimary.withValues(alpha: 0.7),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _googleRedirectError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
