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

    // Input validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        error = "Email and password cannot be empty.";
        isLoading = false;
      });
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        error = "Please enter a valid email address.";
        isLoading = false;
      });
      return;
    }

    // Password length validation
    if (password.length < 6) {
      setState(() {
        error = "Password must be at least 6 characters long.";
        isLoading = false;
      });
      return;
    }

    try {
      _logger.i("🚀 Starting registration for: $email");
      final result = await AuthService.register(email, password);
      _logger.i("✅ Registration successful! Response: $result");

      // If we reach this point, registration was successful
      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Registration Successful!'),
            content: const Text(
              'Your account has been created successfully. You can now log in with your new credentials.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Navigate to login page after dialog is closed
        if (mounted) {
          _logger.i("🧭 Navigating to login page...");
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      _logger.e("❌ Registration error caught in UI: $e");

      if (mounted) {
        setState(() {
          // Parse the error message
          String errorMessage = e.toString();

          // Remove "Exception: " prefix if present
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }

          // Handle specific error types
          String lowerError = errorMessage.toLowerCase();
          if (lowerError.contains('email already exists') ||
              lowerError.contains('already registered') ||
              lowerError.contains('duplicate')) {
            error = "An account with this email already exists.";
          } else if (lowerError.contains('network') ||
              lowerError.contains('connection')) {
            error = "Network error. Please check your connection.";
          } else if (lowerError.contains('timeout')) {
            error = "Request timed out. Please try again.";
          } else if (lowerError.contains('json') ||
              lowerError.contains('parsing')) {
            error = "Server response error. Please try again.";
          } else {
            error = errorMessage;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        passwordController.clear();
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
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
                    : const Text('Register', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
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
