import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/utils/date_helpers.dart';
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

  Future<void> _handleToggle(bool? newValue) async {
    if (_isLoading) return;
    final complete = newValue ?? false;
    setState(() => _isLoading = true);
    try {
      await widget.onToggle(complete);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(complete ? '✅ Task completed!' : '↩️ Task unmarked'),
            backgroundColor: complete ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = !Provider.of<ThemeProvider>(context).isDarkMode;
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
            ? _CompletedCard(
                task: widget.task,
                completedColor: completedColor,
                isLoading: _isLoading,
                onTap: () => _handleToggle(false),
              )
            : _ActiveCard(
                task: widget.task,
                isLightMode: isLightMode,
                isLoading: _isLoading,
                onToggle: _handleToggle,
              ),
      ),
    );
  }
}

// ── Active card ──────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final Task task;
  final bool isLightMode;
  final bool isLoading;
  final Function(bool?) onToggle;

  const _ActiveCard({
    required this.task,
    required this.isLightMode,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: isLoading
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
                onChanged: isLoading ? null : onToggle,
                activeColor: isLightMode ? Colors.green : Colors.teal,
              ),
        title: Text(
          task.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: _Subtitle(task: task),
        trailing: task.isOverdue
            ? const Icon(Icons.warning, color: Colors.orange)
            : task.isDueSoon
            ? const Icon(Icons.access_time, color: Colors.amber)
            : null,
        onTap: isLoading ? null : () => onToggle(true),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final Task task;
  const _Subtitle({required this.task});

  @override
  Widget build(BuildContext context) {
    final hasDesc = task.description != null && task.description!.isNotEmpty;
    final hasDue = task.dueDate != null;
    final hasTeam = task.isTeamTask && task.team != null;

    if (!hasDesc && !hasDue && !hasTeam) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDesc)
          Text(
            task.description!,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            _PriorityChip(priority: task.priority),
            if (hasDue) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.schedule,
                size: 12,
                color: task.isOverdue ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                DateHelpers.shortDueLabel(task.dueDate!),
                style: TextStyle(
                  fontSize: 12,
                  color: task.isOverdue ? Colors.red : Colors.grey,
                  fontWeight: task.isOverdue
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
            if (hasTeam) ...[
              const SizedBox(width: 8),
              const Icon(Icons.group, size: 12, color: Colors.blue),
              const SizedBox(width: 2),
              Text(
                task.team!.name,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Completed card ───────────────────────────────────────────────────────

class _CompletedCard extends StatelessWidget {
  final Task task;
  final Color completedColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _CompletedCard({
    required this.task,
    required this.completedColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    task.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
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
                onTap: isLoading ? null : onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Priority chip ────────────────────────────────────────────────────────

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip({required this.priority});

  static const _colors = <String, Color>{
    'low': Colors.green,
    'medium': Colors.orange,
    'high': Colors.red,
    'urgent': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[priority.toLowerCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
