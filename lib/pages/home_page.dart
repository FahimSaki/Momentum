import 'package:flutter/material.dart';
import 'package:momentum/components/drawer.dart';
import 'package:momentum/components/task_map.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/components/animated_task_tile.dart';
import 'package:momentum/components/completed_tasks.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showCompletedTasks = false;
  final TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final db = Provider.of<TaskDatabase>(context, listen: false);
    db.readTasks();
    // 🔧 REMOVED: Don't call deleteCompletedTasks immediately!
    // The backend scheduler will handle cleanup automatically
  }

  void createNewTask() {
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
      body: ListView(
        children: [
          const HeatMapComponent(),
          Consumer<TaskDatabase>(
            builder: (context, db, _) {
              final activeTasks = db.activeTasks;
              final completedTasks = db.completedTasks;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  ...activeTasks.map((task) {
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
                        context.read<TaskDatabase>().updateTaskCompletion(
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
                    completedTasks: completedTasks,
                    showCompletedTasks: _showCompletedTasks,
                    onChanged: (task) => (value) {
                      context
                          .read<TaskDatabase>()
                          .updateTaskCompletion(task.id, value ?? false);
                    },
                    editTask: editTaskBox,
                    deleteTask: deleteTaskBox,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _showCompletedTasks = expanded;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
