import 'package:flutter/material.dart';
import 'package:habit_tracker/components/drawer.dart';
import 'package:habit_tracker/components/heat_map.dart';
import 'package:habit_tracker/components/habit_list.dart';
import 'package:habit_tracker/database/task_database.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/models/task.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final bool _showCompletedTasks = false;

  @override
  void initState() {
    super.initState();
    // Fetch tasks from API
    Provider.of<TaskDatabase>(context, listen: false).fetchTasks();
  }

  // text controller
  final TextEditingController textController = TextEditingController();

  // * create a new task
  void createNewTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Create a new task',
            hintStyle: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        actions: [
          // save button
          MaterialButton(
            onPressed: () async {
              String newTaskTitle = textController.text;
              if (newTaskTitle.isNotEmpty) {
                final task = Task(
                  id: '',
                  title: newTaskTitle,
                  status: 'pending',
                  assignedTo: '',
                  createdBy: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await context.read<TaskDatabase>().addTask(task);
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
          MaterialButton(
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

  // * check task on/off
  void checkTaskOnOff(bool? p0, Task task) async {
    if (p0 != null) {
      final newStatus = p0 ? 'completed' : 'pending';
      await context
          .read<TaskDatabase>()
          .updateTask(task.id, {'status': newStatus});
    }
  }

  // * edit task box
  void editTaskBox(BuildContext context, Task task) {
    textController.text = task.title;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: textController,
        ),
        actions: [
          MaterialButton(
            onPressed: () async {
              String newTaskTitle = textController.text;
              if (newTaskTitle.isNotEmpty) {
                await context
                    .read<TaskDatabase>()
                    .updateTask(task.id, {'title': newTaskTitle});
              }
              Navigator.pop(context);
              textController.clear();
            },
            child: const Text('Save'),
          ),
          MaterialButton(
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

  // * delete task box
  void deleteTaskBox(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to delete this task?'),
        actions: [
          MaterialButton(
            onPressed: () async {
              await context.read<TaskDatabase>().deleteTask(task.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          MaterialButton(
            onPressed: () {
              Navigator.pop(context);
            },
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
        elevation: 0,
        onPressed: createNewTask,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
      ),
      body: ListView(
        children: [
          // * H E A T M A P
          const HeatMapComponent(),

          // * T A S K  L I S T
          TaskListComponent(
            showCompletedTasks: _showCompletedTasks,
            checkTaskOnOff: checkTaskOnOff,
            editTaskBox: editTaskBox,
            deleteTaskBox: deleteTaskBox,
          ),
        ],
      ),
    );
  }
}
