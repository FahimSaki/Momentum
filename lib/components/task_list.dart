import 'package:flutter/material.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:provider/provider.dart';

class TaskList extends StatefulWidget {
  const TaskList({Key? key}) : super(key: key);

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  bool _showCompletedTasks = false;
  String _filterBy = 'all';
  String _sortBy = 'created';

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
                      initialValue: _filterBy,
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
                      initialValue: _sortBy,
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
                  await db.refreshData();
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
                      // Active tasks section
                      if (sortedTasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Active Tasks (${sortedTasks.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...sortedTasks.map(
                          (task) => TaskTile(
                            key: ValueKey(task.id),
                            task: task,
                            // 🔧 FIXED: Proper completion handler
                            onToggle: (isCompleted) async {
                              try {
                                await db.completeTask(task.id, isCompleted);
                              } catch (e) {
                                // Error handling is now done in TaskTile
                                rethrow;
                              }
                            },
                            onEdit: () => _editTaskDialog(context, task, db),
                            onDelete: () =>
                                _deleteTaskDialog(context, task, db),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Completed tasks section
                      if (completedTasks.isNotEmpty)
                        Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Completed Today (${completedTasks.length})',
                                ),
                              ],
                            ),
                            subtitle: Text(
                              completedTasks.length == 1
                                  ? 'Great job! 1 task completed today.'
                                  : 'Amazing! ${completedTasks.length} tasks completed today.',
                              style: TextStyle(color: Colors.green.shade600),
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
                                    // 🔧 FIXED: Proper uncomplete handler
                                    onToggle: (isCompleted) async {
                                      try {
                                        await db.completeTask(
                                          task.id,
                                          isCompleted,
                                        );
                                      } catch (e) {
                                        rethrow;
                                      }
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

  void _editTaskDialog(BuildContext context, Task task, TaskDatabase db) {
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
                try {
                  await db.updateTask(task.id, {
                    'name': newName,
                    'description': descriptionController.text.trim(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating task: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTaskDialog(BuildContext context, Task task, TaskDatabase db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${task.name}"?'),
            const SizedBox(height: 8),
            if (task.isCompletedToday())
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task was completed today. Deleting it will move the completion to your history.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
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
              try {
                await db.deleteTask(task.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting task: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
