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
  bool _showCompleted = false;
  String _filterBy = 'all';
  String _sortBy = 'created';

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDatabase>(
      builder: (context, db, _) {
        final sorted = _sortTasks(_filterTasks(db.activeTasks));
        final completed = db.completedTasks;

        return Column(
          children: [
            _FilterSortRow(
              filterBy: _filterBy,
              sortBy: _sortBy,
              onFilterChanged: (v) => setState(() => _filterBy = v),
              onSortChanged: (v) => setState(() => _sortBy = v),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: db.refreshData,
                child: ListView(
                  children: [
                    if (sorted.isEmpty && completed.isEmpty)
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
                      if (sorted.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Active Tasks (${sorted.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...sorted.map(
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
                      if (completed.isNotEmpty)
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
                                Text('Completed Today (${completed.length})'),
                              ],
                            ),
                            subtitle: Text(
                              completed.length == 1
                                  ? 'Great job! 1 task completed today.'
                                  : 'Amazing! ${completed.length} tasks completed today.',
                              style: TextStyle(color: Colors.green.shade600),
                            ),
                            initiallyExpanded: _showCompleted,
                            onExpansionChanged: (v) =>
                                setState(() => _showCompleted = v),
                            children: completed
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

  List<Task> _filterTasks(List<Task> tasks) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    switch (_filterBy) {
      case 'overdue':
        return tasks.where((t) => t.isOverdue).toList();
      case 'today':
        return tasks.where((t) {
          if (t.dueDate == null) return false;
          return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) ==
              todayDay;
        }).toList();
      case 'upcoming':
        return tasks
            .where((t) => t.dueDate != null && t.dueDate!.isAfter(todayDay))
            .toList();
      default:
        return tasks;
    }
  }

  List<Task> _sortTasks(List<Task> tasks) {
    final list = List<Task>.from(tasks);
    switch (_sortBy) {
      case 'due':
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'priority':
        const order = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1};
        list.sort(
          (a, b) => (order[b.priority] ?? 2).compareTo(order[a.priority] ?? 2),
        );
        break;
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }
}

class _FilterSortRow extends StatelessWidget {
  final String filterBy;
  final String sortBy;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSortChanged;

  const _FilterSortRow({
    required this.filterBy,
    required this.sortBy,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: filterBy,
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
              onChanged: (v) => onFilterChanged(v ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: sortBy,
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
              onChanged: (v) => onSortChanged(v ?? 'created'),
            ),
          ),
        ],
      ),
    );
  }
}
