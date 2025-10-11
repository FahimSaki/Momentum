import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
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

      // Get user's role and permissions
      _userRole = PermissionHelper.getUserRole(widget.team, db.userId!);
      _permissions = TeamPermissions.forRole(_userRole);

      _logger.i('User role in team: $_userRole');
      _logger.d(
        'Permissions: canCreateTasks=${_permissions.canCreateTasks}, canCompleteTasks=${_permissions.canCompleteTasks}',
      );

      // Select the team to load its tasks
      db.selectTeam(widget.team);

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
            // Go back to team selection
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TeamSelectionPage(),
              ),
            );
          },
        ),
        actions: [
          // Role badge
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

          // Switch team button
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

          // Team info
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

      // ONLY show FAB if user has permission to create tasks
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
          // Show appropriate view based on permissions
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
                // Welcome message with role info
                _buildWelcomeCard(),

                const SizedBox(height: 16),

                // Stats
                const DashboardStats(),

                const SizedBox(height: 16),

                // Tasks section
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

            // Role-specific message
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
        // Active tasks
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
                  if (mounted) {
                    ErrorHandler.showSnackBarError(context, e);
                  }
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

        // Completed tasks
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
                    if (mounted) {
                      ErrorHandler.showSnackBarError(context, e);
                    }
                    rethrow;
                  }
                },
                onEdit: () => _showNoPermissionDialog('edit'),
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

  // Helper methods
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

  void _showTaskCreationDialog() {
    if (!_permissions.canCreateTasks) {
      _showNoPermissionDialog('create tasks');
      return;
    }

    // Import and show your existing TaskCreationDialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Task'),
        content: const Text('Task creation dialog implementation here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _editTaskDialog(BuildContext context, task, TaskDatabase db) {
    // Your existing edit dialog code
  }

  void _deleteTaskDialog(BuildContext context, task, TaskDatabase db) {
    // Your existing delete dialog code
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
}
