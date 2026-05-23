import 'package:flutter/material.dart';
import 'package:momentum/components/task_edit_delete_dialogs.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:provider/provider.dart';

class TaskList extends StatefulWidget {
  const TaskList({super.key});

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
            _buildFilterSortRow(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: db.refreshData,
                child: ListView(
                  children: [
                    if (sortedTasks.isEmpty && completedTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80, left: 16, right: 16),
                        child: Center(
                          child: Text(
                            'No tasks found. Create your first task!',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    else ...[
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
                            onToggle: (v) => db.completeTask(task.id, v),
                            onEdit: () => showEditTaskDialog(context, task, db),
                            onDelete: () =>
                                showDeleteTaskDialog(context, task, db),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (completedTasks.isNotEmpty)
                        Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                const Icon(
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
                            onExpansionChanged: (v) =>
                                setState(() => _showCompletedTasks = v),
                            children: completedTasks
                                .map(
                                  (task) => TaskTile(
                                    key: ValueKey('completed_${task.id}'),
                                    task: task,
                                    onToggle: (v) =>
                                        db.completeTask(task.id, v),
                                    onEdit: () =>
                                        showEditTaskDialog(context, task, db),
                                    onDelete: () =>
                                        showDeleteTaskDialog(context, task, db),
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

  Widget _buildFilterSortRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                DropdownMenuItem(value: 'all', child: Text('All Tasks')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                DropdownMenuItem(value: 'today', child: Text('Due Today')),
                DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
              ],
              onChanged: (v) => setState(() => _filterBy = v ?? 'all'),
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
                DropdownMenuItem(value: 'created', child: Text('Created')),
                DropdownMenuItem(value: 'due', child: Text('Due Date')),
                DropdownMenuItem(value: 'priority', child: Text('Priority')),
                DropdownMenuItem(value: 'name', child: Text('Name')),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'created'),
            ),
          ),
        ],
      ),
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filterBy) {
      case 'overdue':
        return tasks.where((t) => t.isOverdue).toList();
      case 'today':
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) ==
              today;
        }).toList();
      case 'upcoming':
        return tasks
            .where((t) => t.dueDate != null && t.dueDate!.isAfter(today))
            .toList();
      default:
        return tasks;
    }
  }

  List<Task> _sortTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    switch (_sortBy) {
      case 'due':
        sorted.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'priority':
        const order = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1};
        sorted.sort(
          (a, b) => (order[b.priority] ?? 2).compareTo(order[a.priority] ?? 2),
        );
        break;
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      default: // created
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }
}
