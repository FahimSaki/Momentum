import 'dart:ui';
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

  // FIXED: Proper completion handling with loading state
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
    final completedColor = isLightMode
        ? const Color(0xFF10B981)
        : const Color(0xFF34D399);

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
        child: isCompleted
            ? _buildCompletedCard(completedColor, isLightMode)
            : _buildActiveCard(isLightMode),
      ),
    );
  }

  Widget _buildCompletedCard(Color completedColor, bool isLightMode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: Opacity(
              opacity: 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const SizedBox(width: 24, height: 24),
                  title: Text(
                    widget.task.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle:
                      widget.task.description != null &&
                          widget.task.description!.isNotEmpty
                      ? Text(widget.task.description!)
                      : null,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: completedColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: completedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: completedColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: completedColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading ? null : () => _handleToggle(false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(bool isLightMode) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
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
                value: false,
                onChanged: _isLoading ? null : _handleToggle,
                activeColor: isLightMode ? Colors.green : Colors.teal,
              ),
        title: Text(
          widget.task.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
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
                      color: widget.task.isOverdue ? Colors.red : Colors.grey,
                      fontWeight: widget.task.isOverdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
                if (widget.task.isTeamTask) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.group, size: 12, color: Colors.blue),
                  if (widget.task.team != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      widget.task.team!.name,
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
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
        onTap: _isLoading ? null : () => _handleToggle(true),
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
