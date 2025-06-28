/*

 S H O W   B O T H  C O M P L E T E D   A N D   I  N C O M P L E T E D   T A S K S

 */

import 'package:flutter/material.dart';
import 'package:habit_tracker/components/animated_task_tile.dart';
import 'package:habit_tracker/components/completed_tasks.dart';
import 'package:habit_tracker/database/task_database.dart';
import 'package:habit_tracker/models/task.dart';
import 'package:provider/provider.dart';

class TaskListComponent extends StatefulWidget {
  final bool showCompletedTasks;
  final void Function(bool?, Task) checkTaskOnOff;
  final void Function(BuildContext, Task) editTaskBox;
  final void Function(BuildContext, Task) deleteTaskBox;

  const TaskListComponent({
    super.key,
    required this.showCompletedTasks,
    required this.checkTaskOnOff,
    required this.editTaskBox,
    required this.deleteTaskBox,
  });

  @override
  State<TaskListComponent> createState() => _TaskListComponentState();
}

class _TaskListComponentState extends State<TaskListComponent> {
  final Map<String, bool> _removedTasks = {};

  @override
  Widget build(BuildContext context) {
    final taskDatabase = context.watch<TaskDatabase>();
    List<Task> currentTasks = taskDatabase.currentTasks;

    // Update the filtering logic for tasks
    List<Task> uncompletedTasks =
        currentTasks.where((task) => task.status != 'completed').toList();

    List<Task> completedTasks =
        currentTasks.where((task) => task.status == 'completed').toList();

    return Column(
      children: [
        if (uncompletedTasks.isEmpty && completedTasks.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 80, right: 16, left: 16),
            child: Text(
              'No tasks found. Please add a new task.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ] else ...[
          ListView.builder(
            itemCount: uncompletedTasks.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final task = uncompletedTasks[index];
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _removedTasks[task.id] == true
                    ? const SizedBox.shrink()
                    : AnimatedTaskTile(
                        key: ValueKey('uncompleted_${task.id}'),
                        isCompleted: false,
                        text: task.title,
                        onChanged: (value) {
                          if (value == true) {
                            setState(() {
                              _removedTasks[task.id] = true;
                            });
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              widget.checkTaskOnOff(value, task);
                            });
                          } else {
                            widget.checkTaskOnOff(value, task);
                          }
                        },
                        editTask: (context) =>
                            widget.editTaskBox(context, task),
                        deleteTask: (context) =>
                            widget.deleteTaskBox(context, task),
                      ),
              );
            },
          ),
        ],
        const SizedBox(height: 10),
        CompletedTasks(
          completedTasks: completedTasks,
          showCompletedTasks: widget.showCompletedTasks,
          onChanged: (task) => (p0) {
            // Immediately update the UI when unchecking a completed task
            if (p0 == false) {
              setState(() {
                _removedTasks.remove(task.id);
              });
            }
            widget.checkTaskOnOff(p0, task);
          },
          editTask: widget.editTaskBox,
          deleteTask: widget.deleteTaskBox,
          onExpansionChanged: (expanded) {
            setState(() {});
          },
        ),
      ],
    );
  }
}
