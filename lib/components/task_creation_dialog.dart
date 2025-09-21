import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class TaskCreationDialog extends StatefulWidget {
  const TaskCreationDialog({super.key});

  @override
  State<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends State<TaskCreationDialog> {
  final Logger _logger = Logger();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  String _assignmentType = 'individual';
  final List<String> _selectedAssignees = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDatabase>(
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
                  enabled: !_isLoading,
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
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Priority
                DropdownButtonFormField<String>(
                  initialValue: _priority,
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
                  onChanged: _isLoading
                      ? null
                      : (value) {
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
                  onTap: _isLoading
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
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
                    initialValue: _assignmentType,
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
                    onChanged: _isLoading
                        ? null
                        : (value) {
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
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTask,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
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
            onChanged: _isLoading
                ? null
                : (bool? value) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);

      // FIX: Ensure teamId is passed correctly
      final teamId = db.selectedTeam?.id;

      _logger.i(
        'Creating task: name=$name, teamId=$teamId, assignmentType=$_assignmentType',
      );

      // Enhanced task creation with better error handling
      final task = await db.createTask(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        assignedTo: _assignmentType == 'team'
            ? null // Let backend handle team assignment
            : (_selectedAssignees.isEmpty ? null : _selectedAssignees),
        teamId: teamId, // FIX: Pass teamId explicitly
        priority: _priority,
        dueDate: _dueDate,
        assignmentType: _assignmentType,
        tags: [], // Empty tags list
      );

      _logger.i('Task created successfully: ${task.id}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating task', error: e, stackTrace: stackTrace);

      if (mounted) {
        // Better error message extraction
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        // Handle specific error types
        if (errorMessage.toLowerCase().contains('network')) {
          errorMessage = 'Network error - check your connection';
        } else if (errorMessage.toLowerCase().contains('unauthorized')) {
          errorMessage = 'Session expired - please login again';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
}
