import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:provider/provider.dart';

class TaskCreationDialog extends StatefulWidget {
  const TaskCreationDialog({super.key});

  @override
  State<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends State<TaskCreationDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  String _assignmentType = 'individual';
  List<String> _selectedAssignees = [];
  final List<String> _tags = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedTaskDatabase>(
      builder: (context, db, _) {
        final selectedTeam = db.selectedTeam;

        return AlertDialog(
          title: Text(
            selectedTeam != null ? 'Create Team Task' : 'Create Personal Task',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Priority
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _priority = value ?? 'medium';
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Due date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _dueDate != null
                        ? 'Due: ${_dueDate!.toLocal().toString().split(' ')[0]}'
                        : 'Set Due Date',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _dueDate = date;
                      });
                    }
                  },
                ),

                // Team-specific options
                if (selectedTeam != null) ...[
                  const Divider(),
                  Text(
                    'Assignment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  // Assignment type
                  DropdownButtonFormField<String>(
                    value: _assignmentType,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'individual',
                        child: Text('Individual Members'),
                      ),
                      DropdownMenuItem(
                        value: 'team',
                        child: Text('Entire Team'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _assignmentType = value ?? 'individual';
                        if (_assignmentType == 'team') {
                          _selectedAssignees.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Member selection (if individual assignment)
                  if (_assignmentType == 'individual')
                    _buildMemberSelection(selectedTeam),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _createTask, child: const Text('Create')),
          ],
        );
      },
    );
  }

  Widget _buildMemberSelection(Team team) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        children: team.members.map((member) {
          final isSelected = _selectedAssignees.contains(member.user.id);
          return CheckboxListTile(
            title: Text(member.user.name),
            subtitle: Text(member.role),
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedAssignees.add(member.user.id);
                } else {
                  _selectedAssignees.remove(member.user.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  void _createTask() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a task name')));
      return;
    }

    final db = Provider.of<EnhancedTaskDatabase>(context, listen: false);

    try {
      await db.createTask(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        assignedTo: _selectedAssignees.isEmpty ? null : _selectedAssignees,
        priority: _priority,
        dueDate: _dueDate,
        assignmentType: _assignmentType,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating task: $e')));
      }
    }
  }
}
