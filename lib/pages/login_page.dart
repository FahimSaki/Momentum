import 'package:flutter/material.dart';
import 'package:habit_tracker/services/auth_service.dart';
import 'package:habit_tracker/database/habit_database.dart';
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
      final jwt = result['token'];
      final userId = result['userId'];

      // Initialize HabitDatabase with JWT and userId
      final habitDatabase = Provider.of<HabitDatabase>(context, listen: false);
      await habitDatabase.initialize(jwt: jwt, userId: userId);

      // Navigate to your main/home page
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (error != null) ...[
                SizedBox(height: 8),
                Text(error!, style: TextStyle(color: Colors.red)),
              ],
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : login,
                child: isLoading ? CircularProgressIndicator() : Text('Login'),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
