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
import 'package:momentum/pages/team_settings_page.dart';
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
      if (db.userId == null) throw Exception('User not authenticated');

      final freshTeam = await db.getTeamDetails(widget.team.id);
      _userRole = PermissionHelper.getUserRole(freshTeam, db.userId!);
      _permissions = TeamPermissions.forRole(_userRole);
      db.selectTeam(freshTeam);

      setState(() => _isLoading = false);
    } catch (e, stackTrace) {
      _logger.e('Error loading team data', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, e, title: 'Failed to load team');
      }
    }
  }

  Future<void> _showDeleteTeamDialog() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (!widget.team.isOwner(db.userId ?? '')) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE53E3E)),
            SizedBox(width: 10),
            Text('Delete Team'),
          ],
        ),
        content: Text(
          'Permanently delete "${widget.team.name}"?\n\nAll tasks, members and history will be lost. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await db.deleteTeam(widget.team.id);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e, title: 'Delete failed');
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

    final db = Provider.of<TaskDatabase>(context, listen: false);
    final isOwner = widget.team.isOwner(db.userId ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.team.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '${widget.team.members.length} members',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9B99C8)
                    : const Color(0xFF6B66A3),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeamSelectionPage()),
          ),
        ),
        actions: [
          // Role badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              PermissionHelper.getRoleDisplayName(_userRole),
              style: TextStyle(
                color: _getRoleColor(),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              switch (value) {
                case 'details':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamDetailsPage(team: widget.team),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamSettingsPage(team: widget.team),
                    ),
                  );
                  break;
                case 'switch':
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeamSelectionPage(),
                    ),
                  );
                  break;
                case 'delete':
                  _showDeleteTeamDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('Team Details'),
                  ],
                ),
              ),
              if (_permissions.canEditSettings)
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('Switch Workspace'),
                  ],
                ),
              ),
              if (isOwner) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever_rounded,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete Team',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _permissions.canCreateTasks
          ? FloatingActionButton.extended(
              onPressed: _showTaskCreationDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Task',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (!_permissions.canViewTasks) return _buildNoAccessView();
          if (db.currentTasks.isEmpty) return _buildEmptyStateView();
          return RefreshIndicator(
            onRefresh: () async => await db.refreshData(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildWelcomeCard(isDark),
                const SizedBox(height: 16),
                const DashboardStats(),
                const SizedBox(height: 20),
                _buildTasksSection(db, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getRoleGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_getRoleIcon(), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are a ${PermissionHelper.getRoleDisplayName(_userRole)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _getRoleDescription(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(TaskDatabase db, bool isDark) {
    final activeTasks = db.activeTasks;
    final completedTasks = db.completedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Tasks (${activeTasks.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark
                        ? const Color(0xFFE8E6FF)
                        : const Color(0xFF1C1B3A),
                  ),
                ),
              ],
            ),
          ),
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
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1929) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D2C44)
                      : const Color(0xFFEDE9FE),
                ),
              ),
              child: ExpansionTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                ),
                title: Text(
                  'Completed Today (${completedTasks.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFE8E6FF)
                        : const Color(0xFF1C1B3A),
                  ),
                ),
                subtitle: Text(
                  completedTasks.length == 1
                      ? 'Great work! 🎉'
                      : 'Amazing! ${completedTasks.length} done! 🎉',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 12,
                  ),
                ),
                children: completedTasks
                    .map(
                      (task) => TaskTile(
                        key: ValueKey('completed_${task.id}'),
                        task: task,
                        onToggle: (isCompleted) async {
                          if (!_permissions.canCompleteTasks) {
                            ErrorHandler.showSnackBarError(
                              context,
                              'No permission to modify task completion',
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
                        onEdit: () =>
                            _showNoPermissionDialog('edit a completed task'),
                        onDelete: () => _showNoPermissionDialog('delete'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyStateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tasks yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _permissions.canCreateTasks
                  ? 'Create the first task for your team'
                  : 'Tasks assigned by admins will appear here',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B66A3), fontSize: 14),
            ),
            if (_permissions.canCreateTasks) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showTaskCreationDialog,
                icon: const Icon(Icons.add_rounded),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 40,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Access',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'You don\'t have permission to view team tasks',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B66A3)),
          ),
        ],
      ),
    );
  }

  void _showTaskCreationDialog() {
    if (!_permissions.canCreateTasks) {
      _showNoPermissionDialog('create tasks');
      return;
    }
    showDialog(context: context, builder: (_) => const TaskCreationDialog());
  }

  void _editTaskDialog(BuildContext context, Task task, TaskDatabase db) {
    final nameController = TextEditingController(text: task.name);
    final descController = TextEditingController(text: task.description ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Task Name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await db.updateTask(task.id, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task updated'),
                      backgroundColor: Color(0xFF22C55E),
                    ),
                  );
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
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
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task'),
        content: Text('Delete "${task.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await db.deleteTask(task.id);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task deleted'),
                      backgroundColor: Color(0xFF22C55E),
                    ),
                  );
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNoPermissionDialog(String action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Text(
          'You don\'t have permission to $action.\n\nOnly owners and admins can do this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  List<Color> _getRoleGradient() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return [const Color(0xFF7C3AED), const Color(0xFF9D4EDD)];
      case 'admin':
        return [const Color(0xFFD97706), const Color(0xFFF59E0B)];
      default:
        return [const Color(0xFF2563EB), const Color(0xFF3B82F6)];
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return Icons.star_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getRoleDescription() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return 'Full control over team, settings, members, and tasks';
      case 'admin':
        return 'Can create, edit, delete tasks and invite members';
      default:
        return 'Can view and complete tasks assigned to you';
    }
  }
}
