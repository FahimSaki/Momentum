import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _isLoading = false;

  // 🔧 FIXED: Proper completion handling with loading state
  Future<void> _handleToggle(bool? newValue) async {
    if (_isLoading) return; // Prevent multiple simultaneous calls

    final bool shouldComplete = newValue ?? false;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onToggle(shouldComplete);

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldComplete ? '✅ Task completed!' : '↩️ Task unmarked',
            ),
            backgroundColor: shouldComplete ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLightMode = !themeProvider.isDarkMode;
    final isCompleted = widget.task.isCompletedToday();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => widget.onEdit(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => widget.onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: Card(
          elevation: isCompleted ? 0 : 2,
          color: isCompleted
              ? (isLightMode ? Colors.green.shade100 : Colors.green.shade800)
              : Theme.of(context).colorScheme.surface,
          child: ListTile(
            leading: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLightMode ? Colors.green : Colors.teal,
                      ),
                    ),
                  )
                : Checkbox(
                    value: isCompleted,
                    onChanged: _isLoading ? null : _handleToggle,
                    activeColor: isLightMode ? Colors.green : Colors.teal,
                  ),
            title: Text(
              widget.task.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? Colors.grey
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.task.description != null &&
                    widget.task.description!.isNotEmpty)
                  Text(
                    widget.task.description!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Priority indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(widget.task.priority),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.task.priority.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (widget.task.dueDate != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: widget.task.isOverdue ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(widget.task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.task.isOverdue
                              ? Colors.red
                              : Colors.grey,
                          fontWeight: widget.task.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],

                    if (widget.task.isTeamTask) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.group, size: 12, color: Colors.blue),
                      if (widget.task.team != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          widget.task.team!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ],

                    // 🔧 NEW: Show completion status indicator
                    if (isCompleted) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: widget.task.isOverdue
                ? const Icon(Icons.warning, color: Colors.orange)
                : widget.task.isDueSoon
                ? const Icon(Icons.access_time, color: Colors.amber)
                : null,
            // 🔧 NEW: Make entire tile tappable for completion
            onTap: _isLoading ? null : () => _handleToggle(!isCompleted),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference < 0) return '${-difference}d overdue';
    if (difference <= 7) return '${difference}d left';

    return '${dueDate.month}/${dueDate.day}';
  }
}
