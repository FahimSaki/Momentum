import 'package:flutter/material.dart';
import 'package:momentum/components/drawer.dart';
import 'package:momentum/components/task_map.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/components/animated_task_tile.dart';
import 'package:momentum/components/completed_tasks.dart';
import 'package:momentum/services/auth_service.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showCompletedTasks = false;
  bool _isInitializing = false;
  bool _initializationFailed = false;
  final TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ensureInitialized();
  }

  // 🔧 IMPROVED: Better initialization handling
  Future<void> _ensureInitialized() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);

    // 🔧 NEW: Don't show loading if database was previously initialized
    // This prevents the loading state during logout
    if (!db.isInitialized && !_initializationFailed) {
      setState(() {
        _isInitializing = true;
      });

      try {
        // Get stored auth data
        final authData = await AuthService.getStoredAuthData();

        if (authData != null && mounted) {
          // Validate token
          final isValidToken = await AuthService.validateToken();

          if (isValidToken && mounted) {
            // Initialize TaskDatabase
            await db.initialize(
              jwt: authData['token'],
              userId: authData['userId'],
            );
          } else {
            // Invalid token, redirect to login
            if (mounted) {
              final navigator = Navigator.of(context);
              await AuthService.logout();
              navigator.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
              return;
            }
          }
        } else {
          // No auth data, redirect to login
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
            return;
          }
        }
      } catch (e) {
        // Error during initialization
        if (mounted) {
          setState(() {
            _initializationFailed = true;
          });

          final navigator = Navigator.of(context);
          await AuthService.logout();
          navigator.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
          return;
        }
      } finally {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } else if (db.isInitialized) {
      // Already initialized, just refresh tasks
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && db.isInitialized) {
          db.readTasks();
        }
      });
    }
  }

  void createNewTask() {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (!db.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, app is loading...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Create a new task',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final newTaskName = textController.text.trim();
              if (newTaskName.isNotEmpty) {
                context.read<TaskDatabase>().addTask(newTaskName);
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void editTaskBox(BuildContext context, Task task) {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (!db.isInitialized) return;

    textController.text = task.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                context.read<TaskDatabase>().updateTaskName(task.id, newName);
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void deleteTaskBox(BuildContext context, Task task) {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (!db.isInitialized) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<TaskDatabase>().deleteTask(task.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: const MyDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewTask,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          // 🔧 IMPROVED: Only show loading during initial app startup, not during logout
          if (_isInitializing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your tasks...'),
                ],
              ),
            );
          }

          // 🔧 NEW: If initialization failed, show error
          if (_initializationFailed) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to load tasks. Please restart the app.'),
                ],
              ),
            );
          }

          // 🔧 IMPROVED: If not initialized but not initializing, redirect to login
          if (!db.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            });
            return const SizedBox
                .shrink(); // Return empty widget while redirecting
          }

          return ListView(
            children: [
              const HeatMapComponent(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  ...db.activeTasks.map((task) {
                    final isCompletedToday = task.completedDays.any((d) {
                      final localDate = d.toLocal();
                      final now = DateTime.now();
                      return localDate.year == now.year &&
                          localDate.month == now.month &&
                          localDate.day == now.day;
                    });

                    return AnimatedTaskTile(
                      key: ValueKey(task.id),
                      text: task.name,
                      isCompleted: isCompletedToday,
                      onChanged: (value) {
                        db.updateTaskCompletion(
                          task.id,
                          value ?? false,
                        );
                      },
                      editTask: (context) => editTaskBox(context, task),
                      deleteTask: (context) => deleteTaskBox(context, task),
                    );
                  }),
                  const SizedBox(height: 12),
                  CompletedTasks(
                    completedTasks: db.completedTasks,
                    showCompletedTasks: _showCompletedTasks,
                    onChanged: (task) => (value) {
                      db.updateTaskCompletion(task.id, value ?? false);
                    },
                    editTask: editTaskBox,
                    deleteTask: deleteTaskBox,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _showCompletedTasks = expanded;
                      });
                    },
                  ),
                  // Show message if no tasks
                  if (db.activeTasks.isEmpty && db.completedTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80, right: 16, left: 16),
                      child: Center(
                        child: Text(
                          'No tasks found. Please add a new task.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
