// lib/pages/register_page.dart - WITH NAME FIELD
import 'package:flutter/material.dart';
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
  final nameController = TextEditingController(); // ✅ ADD NAME FIELD
  final Logger _logger = Logger();
  bool isLoading = false;
  String? error;

  void register() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim(); // ✅ GET NAME FROM USER INPUT

    // Enhanced input validation
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() {
        error = "Please fill in all fields.";
        isLoading = false;
      });
      return;
    }

    // Better email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        error = "Please enter a valid email address.";
        isLoading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        error = "Password must be at least 6 characters long.";
        isLoading = false;
      });
      return;
    }

    if (name.length < 2) {
      setState(() {
        error = "Name must be at least 2 characters long.";
        isLoading = false;
      });
      return;
    }

    try {
      _logger.i("🚀 Starting registration for: $email with name: $name");

      // ✅ PASS ALL THREE PARAMETERS
      final result = await AuthService.register(email, password, name);

      _logger.i("✅ Registration successful! Response: $result");

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Welcome to Momentum!'),
            content: Text(
              'Hi $name! Your account has been created successfully. You can now log in and start managing your tasks.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Get Started'),
              ),
            ],
          ),
        );

        if (mounted) {
          _logger.i("🧭 Navigating to login page...");
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      _logger.e("❌ Registration error caught in UI: $e");

      if (mounted) {
        setState(() {
          String errorMessage = e.toString();

          // Remove "Exception: " prefix if present
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }

          // Handle specific error types
          String lowerError = errorMessage.toLowerCase();
          if (lowerError.contains('email already exists') ||
              lowerError.contains('already registered') ||
              lowerError.contains('user already exists') ||
              lowerError.contains('duplicate')) {
            error =
                "An account with this email already exists. Try logging in instead.";
          } else if (lowerError.contains('network') ||
              lowerError.contains('connection') ||
              lowerError.contains('socket')) {
            error =
                "Network error. Please check your connection and try again.";
          } else if (lowerError.contains('timeout')) {
            error = "Request timed out. Please try again.";
          } else {
            error = "Registration failed: $errorMessage";
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Clear password for security
        passwordController.clear();
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose(); // ✅ DISPOSE NAME CONTROLLER
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                  ).colorScheme.inversePrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),

              // ✅ NAME FIELD - FIRST
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: UnderlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  helperText: 'Enter your first and last name',
                ),
                textCapitalization: TextCapitalization.words,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),

              // EMAIL FIELD
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

              // PASSWORD FIELD
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: UnderlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Must be at least 6 characters',
                ),
                obscureText: true,
                enabled: !isLoading,
              ),

              // ERROR DISPLAY
              if (error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
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

              // REGISTER BUTTON
              ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 16),

              // LOGIN LINK
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
