import 'package:flutter/material.dart';
import 'package:momentum/components/task_creation_dialog.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_permissions.dart';
import 'package:momentum/helpers/permission_helper.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/components/error_handler.dart';
import 'package:momentum/components/dashboard_stats.dart';
import 'package:momentum/pages/team_details_page.dart';
import 'package:momentum/pages/team_selection_page.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class TeamHomePage extends StatefulWidget {
  final Team team;

  const TeamHomePage({super.key, required this.team});

  @override
  State<TeamHomePage> createState() => _TeamHomePageState();
}

class _TeamHomePageState extends State<TeamHomePage> {
  final Logger _logger = Logger();
  bool _isLoading = true;
  String _userRole = 'member';
  TeamPermissions _permissions = TeamPermissions.member;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);

      if (db.userId == null) {
        throw Exception('User not authenticated');
      }

      final freshTeam = await db.getTeamDetails(widget.team.id);

      _userRole = PermissionHelper.getUserRole(freshTeam, db.userId!);
      _permissions = TeamPermissions.forRole(_userRole);

      _logger.i('User role in team: $_userRole');

      db.selectTeam(freshTeam);

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _logger.e('Error loading team data', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHandler.showError(context, e, title: 'Failed to load team');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.team.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TeamSelectionPage(),
              ),
            );
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              PermissionHelper.getRoleDisplayName(_userRole),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Team/Workspace',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeamSelectionPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamDetailsPage(team: widget.team),
                ),
              );
            },
          ),
        ],
      ),

      floatingActionButton: _permissions.canCreateTasks
          ? FloatingActionButton(
              onPressed: _showTaskCreationDialog,
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,

      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (!_permissions.canViewTasks) {
            return _buildNoAccessView();
          }

          if (db.currentTasks.isEmpty) {
            return _buildEmptyStateView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await db.refreshData();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 16),
                const DashboardStats(),
                const SizedBox(height: 16),
                _buildTasksSection(db),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.team.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.team.members.length} members',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRoleColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getRoleIcon(), size: 16, color: _getRoleColor()),
                      const SizedBox(width: 8),
                      Text(
                        'You are a ${PermissionHelper.getRoleDisplayName(_userRole).toLowerCase()}',
                        style: TextStyle(
                          color: _getRoleColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRoleDescription(),
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection(TaskDatabase db) {
    final activeTasks = db.activeTasks;
    final completedTasks = db.completedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeTasks.isNotEmpty) ...[
          Text(
            'Active Tasks (${activeTasks.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...activeTasks.map((task) {
            final canEdit = _permissions.canEditTask(
              task.assignedBy?.id ?? '',
              db.userId ?? '',
            );
            final canDelete = _permissions.canDeleteTask(
              task.assignedBy?.id ?? '',
              db.userId ?? '',
            );

            return TaskTile(
              key: ValueKey(task.id),
              task: task,
              onToggle: (isCompleted) async {
                if (!_permissions.canCompleteTasks) {
                  ErrorHandler.showSnackBarError(
                    context,
                    'You do not have permission to complete tasks',
                  );
                  return;
                }
                try {
                  await db.completeTask(task.id, isCompleted);
                } catch (e) {
                  if (mounted) ErrorHandler.showSnackBarError(context, e);
                  rethrow;
                }
              },
              onEdit: canEdit
                  ? () => _editTaskDialog(context, task, db)
                  : () => _showNoPermissionDialog('edit'),
              onDelete: canDelete
                  ? () => _deleteTaskDialog(context, task, db)
                  : () => _showNoPermissionDialog('delete'),
            );
          }),
        ],

        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          ExpansionTile(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('Completed Today (${completedTasks.length})'),
              ],
            ),
            subtitle: Text(
              completedTasks.length == 1
                  ? 'Great job! 1 task completed today.'
                  : 'Amazing! ${completedTasks.length} tasks completed today.',
              style: TextStyle(color: Colors.green.shade600),
            ),
            children: completedTasks.map((task) {
              return TaskTile(
                key: ValueKey('completed_${task.id}'),
                task: task,
                onToggle: (isCompleted) async {
                  if (!_permissions.canCompleteTasks) {
                    ErrorHandler.showSnackBarError(
                      context,
                      'You do not have permission to modify task completion',
                    );
                    return;
                  }
                  try {
                    await db.completeTask(task.id, isCompleted);
                  } catch (e) {
                    if (mounted) ErrorHandler.showSnackBarError(context, e);
                    rethrow;
                  }
                },
                onEdit: () => _showNoPermissionDialog('edit a completed task'),
                onDelete: () => _showNoPermissionDialog('delete'),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyStateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No tasks yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              _permissions.canCreateTasks
                  ? 'Create the first task for your team'
                  : 'Tasks created by admins will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_permissions.canCreateTasks) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showTaskCreationDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No Access',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              'You do not have permission to view team tasks',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showTaskCreationDialog() {
    if (!_permissions.canCreateTasks) {
      _showNoPermissionDialog('create tasks');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => const TaskCreationDialog(),
    );
  }

  void _editTaskDialog(BuildContext context, Task task, TaskDatabase db) {
    final nameController = TextEditingController(text: task.name);
    final descriptionController = TextEditingController(
      text: task.description ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              try {
                await db.updateTask(task.id, {
                  'name': newName,
                  'description': descriptionController.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error updating task: ${e.toString().replaceFirst('Exception: ', '')}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTaskDialog(BuildContext context, Task task, TaskDatabase db) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${task.name}"?'),
            const SizedBox(height: 8),
            if (task.isCompletedToday())
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task was completed today. Deleting it will move the completion to history.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await db.deleteTask(task.id);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error deleting task: ${e.toString().replaceFirst('Exception: ', '')}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNoPermissionDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Text(
          'You do not have permission to $action.\n\nOnly team owners and admins can perform this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _getRoleColor() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return Icons.star;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getRoleDescription() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return 'Full control over team settings, members, and tasks';
      case 'admin':
        return 'Can create, edit, and delete tasks, and invite members';
      default:
        return 'Can view and complete tasks assigned to you';
    }
  }
}
