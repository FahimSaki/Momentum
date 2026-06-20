import 'package:flutter/material.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/pages/email_verification_page.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:logger/logger.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final Logger _logger = Logger();
  bool isLoading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void register() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() {
        error = 'Please fill in all fields.';
        isLoading = false;
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        error = 'Please enter a valid email address.';
        isLoading = false;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        error = 'Password must be at least 6 characters.';
        isLoading = false;
      });
      return;
    }
    if (name.length < 2) {
      setState(() {
        error = 'Name must be at least 2 characters.';
        isLoading = false;
      });
      return;
    }

    try {
      _logger.i('Registering: $email');
      final result = await AuthService.instance.register(email, password, name);

      if (!mounted) return;

      // Registration now requires email verification before login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EmailVerificationPage(email: result['email'] as String),
        ),
      );
    } catch (e) {
      _logger.e('Registration error: $e');
      if (mounted) {
        String msg = e.toString().replaceFirst('Exception: ', '');
        final lower = msg.toLowerCase();
        if (lower.contains('already exists') || lower.contains('duplicate')) {
          msg =
              'An account with this email already exists. Try logging in instead.';
        } else if (lower.contains('network') || lower.contains('socket')) {
          msg = 'Network error. Please check your connection.';
        }
        setState(() => error = msg);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        passwordController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: AppWidths.authForm,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Join Momentum',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your account to get started',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.inversePrimary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                helperText: 'At least 6 characters',
              ),
              obscureText: true,
              enabled: !isLoading,
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : register,
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
                  : const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}
