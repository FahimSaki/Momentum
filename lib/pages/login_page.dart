import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/session_cubit.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/pages/email_verification_page.dart';
import 'package:momentum/pages/forgot_password_page.dart';
import 'package:momentum/pages/two_factor_page.dart';
import 'package:momentum/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isGoogleLoading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _initAndNavigate(String jwt, String userId) async {
    final taskCubit = context.read<TaskCubit>();
    final sessionCubit = context.read<SessionCubit>();
    // Same three-way OR the original checked on db.isInitialized /
    // db.jwtToken / db.userId — preserved exactly rather than
    // simplified to sessionCubit.state.isAuthenticated, which is an AND
    // of the last two, not an OR.
    if (taskCubit.state.isInitialized ||
        sessionCubit.state.jwtToken != null ||
        sessionCubit.state.userId != null) {
      await taskCubit.clearData();
    }
    await taskCubit.initializeSession(jwt: jwt, userId: userId);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void login() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await AuthService.instance.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result['requiresVerification'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EmailVerificationPage(email: result['email'] as String),
          ),
        );
        return;
      }

      if (result['requiresTwoFactor'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TwoFactorPage(email: result['email'] as String),
          ),
        );
        return;
      }

      await _initAndNavigate(
        result['token'] as String,
        result['userId'] as String,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Mobile only — drives the native account picker via authenticate().
  void loginWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
      error = null;
    });
    try {
      final result = await AuthService.instance.googleSignIn();
      if (!mounted) return;

      if (result['requiresTwoFactor'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TwoFactorPage(email: result['email'] as String),
          ),
        );
        return;
      }

      await _initAndNavigate(
        result['token'] as String,
        result['userId'] as String,
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (!msg.contains('cancelled')) {
          setState(() => error = msg);
        }
      }
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  /// Web only — full-page redirect to Google. No popup, so there's nothing
  /// for COOP to block anywhere in this flow. This navigates away
  /// immediately; the result (including a possible 2FA challenge) is
  /// picked up on SplashPage once Google redirects back (see
  /// splash_page.dart).
  void _loginWithGoogleWeb() {
    setState(() => isGoogleLoading = true);
    AuthService.instance.beginWebGoogleRedirect();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ResponsiveCenter(
        maxWidth: AppWidths.authForm,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Momentum',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.inversePrimary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading && !isGoogleLoading,
              onSubmitted: (_) => login(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              enabled: !isLoading && !isGoogleLoading,
              onSubmitted: (_) => login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: (isLoading || isGoogleLoading)
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                child: const Text('Forgot password?'),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (isLoading || isGoogleLoading) ? null : login,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.inversePrimary.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: (isLoading || isGoogleLoading)
                  ? null
                  : (kIsWeb ? _loginWithGoogleWeb : loginWithGoogle),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF3D3B5C)
                      : const Color(0xFFDDD6FE),
                ),
              ),
              child: isGoogleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: (isLoading || isGoogleLoading)
                  ? null
                  : () => Navigator.pushReplacementNamed(context, '/register'),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
