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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedTeam != null
                                ? 'New Team Task'
                                : 'New Personal Task',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selectedTeam != null)
                            Text(
                              selectedTeam.name,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task name
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Task Name *',
                          prefixIcon: Icon(
                            Icons.drive_file_rename_outline_rounded,
                          ),
                        ),
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        maxLines: 2,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 14),

                      // Priority
                      DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          prefixIcon: Icon(Icons.flag_rounded),
                        ),
                        items: [
                          _priorityItem('low', 'Low', const Color(0xFF22C55E)),
                          _priorityItem(
                            'medium',
                            'Medium',
                            const Color(0xFFF59E0B),
                          ),
                          _priorityItem(
                            'high',
                            'High',
                            const Color(0xFFF97316),
                          ),
                          _priorityItem(
                            'urgent',
                            'Urgent',
                            const Color(0xFFE53E3E),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(() => _priority = v ?? 'medium'),
                      ),
                      const SizedBox(height: 14),

                      // Due date
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setState(() => _dueDate = date);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF232236)
                                : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2D2C44)
                                  : const Color(0xFFDDD6FE),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: _dueDate != null
                                    ? const Color(0xFF6366F1)
                                    : (isDark
                                          ? const Color(0xFF9B99C8)
                                          : const Color(0xFF6B66A3)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _dueDate != null
                                    ? 'Due: ${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                    : 'Set due date (optional)',
                                style: TextStyle(
                                  color: _dueDate != null
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.inversePrimary
                                      : (isDark
                                            ? const Color(0xFF5A587A)
                                            : const Color(0xFFB0ADDB)),
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _dueDate = null),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isDark
                                        ? const Color(0xFF9B99C8)
                                        : const Color(0xFF6B66A3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Team-specific options
                      if (selectedTeam != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _assignmentType,
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            prefixIcon: Icon(Icons.group_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'individual',
                              child: Text('Select Members'),
                            ),
                            DropdownMenuItem(
                              value: 'team',
                              child: Text('Entire Team'),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (v) => setState(() {
                                  _assignmentType = v ?? 'individual';
                                  if (_assignmentType == 'team') {
                                    _selectedAssignees.clear();
                                  }
                                }),
                        ),
                        if (_assignmentType == 'individual') ...[
                          const SizedBox(height: 14),
                          _buildMemberSelection(selectedTeam, isDark),
                        ],
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createTask,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Create Task',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _priorityItem(
    String value,
    String label,
    Color color,
  ) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildMemberSelection(Team team, bool isDark) {
    // FIX: All members are selectable including the current user (owner/admin)
    final members = team.members;

    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232236) : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFDDD6FE),
          ),
        ),
        child: const Text(
          'No members to assign to.',
          style: TextStyle(color: Color(0xFF6B66A3)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedAssignees.isEmpty
              ? 'Select assignees (leave empty to assign yourself)'
              : '${_selectedAssignees.length} selected',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF9B99C8) : const Color(0xFF6B66A3),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF232236) : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFDDD6FE),
            ),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: members.map((member) {
              final isSelected = _selectedAssignees.contains(member.user.id);
              return CheckboxListTile(
                dense: true,
                title: Text(
                  member.user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  member.role,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9B99C8)
                        : const Color(0xFF6B66A3),
                  ),
                ),
                secondary: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(
                    0xFF6366F1,
                  ).withValues(alpha: 0.15),
                  child: Text(
                    member.user.initials,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                value: isSelected,
                activeColor: const Color(0xFF6366F1),
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
        ),
      ],
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

    setState(() => _isLoading = true);

    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      final teamId = db.selectedTeam?.id;

      await db.createTask(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        // If individual mode with no selections, backend assigns to creator
        assignedTo: _assignmentType == 'team' || _selectedAssignees.isEmpty
            ? null
            : _selectedAssignees,
        teamId: teamId,
        priority: _priority,
        dueDate: _dueDate,
        assignmentType: _assignmentType,
        tags: [],
      );

      _logger.i('Task created successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Task created!'),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating task', error: e, stackTrace: stackTrace);
      if (mounted) {
        String msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
