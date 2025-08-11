import 'package:flutter/material.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String? error;

  void login() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await AuthService.login(
        emailController.text,
        passwordController.text,
      );

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      final jwt = result['token'];
      final userId = result['userId'];

      if (jwt == null || userId == null) {
        // Check mounted before setState
        if (!mounted) return;
        setState(() {
          error = "Invalid login response from server.";
          isLoading = false;
        });
        return;
      }

      // Initialize TaskDatabase with JWT and userId
      final taskDatabase = Provider.of<TaskDatabase>(context, listen: false);
      await taskDatabase.initialize(jwt: jwt, userId: userId);

      // Check mounted before navigation
      if (!mounted) return;
      // Navigate to your main/home page
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Check mounted before setState
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
    } finally {
      // Check mounted before final setState
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Momentum',
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
                onPressed: isLoading ? null : login,
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
                    : const Text('Login', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pushReplacementNamed(context, '/register');
                      },
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
