import 'package:flutter/material.dart';
import 'package:habit_tracker/models/task.dart';
import 'package:habit_tracker/components/animated_task_tile.dart';

class CompletedTasks extends StatelessWidget {
  final List<Task> completedTasks;
  final bool showCompletedTasks;
  final ValueChanged<bool?> Function(Task) onChanged;
  final void Function(BuildContext, Task) editTask;
  final void Function(BuildContext, Task) deleteTask;
  final ValueChanged<bool> onExpansionChanged;

  const CompletedTasks({
    super.key,
    required this.completedTasks,
    required this.showCompletedTasks,
    required this.onChanged,
    required this.editTask,
    required this.deleteTask,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (completedTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            cardColor: Theme.of(context).colorScheme.surface,
          ),
          child: ExpansionTile(
            title: Text('Completed (${completedTasks.length})'),
            initiallyExpanded: showCompletedTasks,
            onExpansionChanged: onExpansionChanged,
            backgroundColor: Theme.of(context).colorScheme.surface,
            collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
            children: completedTasks.map((task) {
              return AnimatedTaskTile(
                key: ValueKey(task.id),
                isCompleted: true,
                text: task.title,
                onChanged: (value) {
                  if (value != null) {
                    onChanged(task)(value);
                  }
                },
                editTask: (context) => editTask(context, task),
                deleteTask: (context) => deleteTask(context, task),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
