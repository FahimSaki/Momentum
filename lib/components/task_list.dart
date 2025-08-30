import 'package:flutter/material.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:provider/provider.dart';

class TaskList extends StatefulWidget {
  const askList({super.key});

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  bool _showCompletedTasks = false;
  String _filterBy = 'all'; // 'all', 'overdue', 'today', 'upcoming'
  String _sortBy = 'created'; // 'created', 'due', 'priority', 'name'

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDatabase>(
      builder: (context, db, _) {
        final filteredTasks = _filterTasks(db.activeTasks);
        final sortedTasks = _sortTasks(filteredTasks);
        final completedTasks = db.completedTasks;

        return Column(
          children: [
            // Filter and sort controls
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterBy,
                      decoration: const InputDecoration(
                        labelText: 'Filter',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Tasks'),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Overdue'),
                        ),
                        DropdownMenuItem(
                          value: 'today',
                          child: Text('Due Today'),
                        ),
                        DropdownMenuItem(
                          value: 'upcoming',
                          child: Text('Upcoming'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterBy = value ?? 'all';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'created',
                          child: Text('Created'),
                        ),
                        DropdownMenuItem(value: 'due', child: Text('Due Date')),
                        DropdownMenuItem(
                          value: 'priority',
                          child: Text('Priority'),
                        ),
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value ?? 'created';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await db._refreshData();
                },
                child: ListView(
                  children: [
                    // Active tasks
                    if (sortedTasks.isEmpty && completedTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80, right: 16, left: 16),
                        child: Center(
                          child: Text(
                            'No tasks found. Create your first task!',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    else ...[
                      ...sortedTasks.map(
                        (task) => TaskTile(
                          key: ValueKey(task.id),
                          task: task,
                          onToggle: (isCompleted) {
                            db.completeTask(task.id, isCompleted);
                          },
                          onEdit: () => _editTaskDialog(context, task, db),
                          onDelete: () => _deleteTaskDialog(context, task, db),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Completed tasks section
                      if (completedTasks.isNotEmpty)
                        Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text(
                              'Completed Today (${completedTasks.length})',
                            ),
                            initiallyExpanded: _showCompletedTasks,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _showCompletedTasks = expanded;
                              });
                            },
                            children: completedTasks
                                .map(
                                  (task) => TaskTile(
                                    key: ValueKey('completed_${task.id}'),
                                    task: task,
                                    onToggle: (isCompleted) {
                                      db.completeTask(task.id, isCompleted);
                                    },
                                    onEdit: () =>
                                        _editTaskDialog(context, task, db),
                                    onDelete: () =>
                                        _deleteTaskDialog(context, task, db),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filterBy) {
      case 'overdue':
        return tasks.where((task) => task.isOverdue).toList();
      case 'today':
        return tasks
            .where(
              (task) =>
                  task.dueDate != null &&
                  DateTime(
                        task.dueDate!.year,
                        task.dueDate!.month,
                        task.dueDate!.day,
                      ) ==
                      today,
            )
            .toList();
      case 'upcoming':
        return tasks
            .where(
              (task) => task.dueDate != null && task.dueDate!.isAfter(today),
            )
            .toList();
      default:
        return tasks;
    }
  }

  List<Task> _sortTasks(List<Task> tasks) {
    final sortedTasks = List<Task>.from(tasks);

    switch (_sortBy) {
      case 'due':
        sortedTasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'priority':
        final priorityOrder = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1};
        sortedTasks.sort((a, b) {
          final aPriority = priorityOrder[a.priority] ?? 2;
          final bPriority = priorityOrder[b.priority] ?? 2;
          return bPriority.compareTo(aPriority);
        });
        break;
      case 'name':
        sortedTasks.sort((a, b) => a.name.compareTo(b.name));
        break;
      default: // 'created'
        sortedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return sortedTasks;
  }

  void _editTaskDialog(
    BuildContext context,
    Task task,
    TaskDatabase db,
  ) {
    final nameController = TextEditingController(text: task.name);
    final descriptionController = TextEditingController(
      text: task.description ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Task Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await db.updateTask(task.id, {
                  'name': newName,
                  'description': descriptionController.text.trim(),
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTaskDialog(
    BuildContext context,
    Task task,
    TaskDatabase db,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.deleteTask(task.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
