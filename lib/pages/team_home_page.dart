import 'package:flutter/material.dart';
import 'package:momentum/components/dashboard_stats.dart';
import 'package:momentum/components/error_handler.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/utils/role_helpers.dart';
import 'package:momentum/components/task_creation_dialog.dart';
import 'package:momentum/components/task_edit_delete_dialogs.dart';
import 'package:momentum/components/task_tile.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/helpers/permission_helper.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_permissions.dart';
import 'package:momentum/pages/team_details_page.dart';
import 'package:momentum/pages/team_selection_page.dart';
import 'package:momentum/pages/team_settings_page.dart';
import 'package:momentum/pages/user_search_page.dart';
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
      final fresh = await db.getTeamDetails(widget.team.id);
      _userRole = PermissionHelper.getUserRole(fresh, db.userId!);
      _permissions = TeamPermissions.forRole(_userRole);
      db.selectTeam(fresh);
      setState(() => _isLoading = false);
    } catch (e, st) {
      _logger.e('Error loading team', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, e, title: 'Failed to load team');
      }
    }
  }

  Future<void> _confirmDeleteTeam() async {
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
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.deleteTeam(widget.team.id);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e, title: 'Delete failed');
    }
  }

  Future<void> _confirmLeaveTeam() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 10),
            Text('Leave Team'),
          ],
        ),
        content: Text(
          'Are you sure you want to leave "${widget.team.name}"?\n\n'
          'You will lose access to all team tasks and will need a new invitation to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await db.leaveTeam(widget.team.id);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have left "${widget.team.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Could not leave team');
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: RoleHelpers.color(_userRole).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              RoleHelpers.displayName(_userRole),
              style: TextStyle(
                color: RoleHelpers.color(_userRole),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (v) {
              switch (v) {
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
                case 'invite':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserSearchPage(
                        teamId: widget.team.id,
                        teamName: widget.team.name,
                      ),
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
                case 'leave':
                  _confirmLeaveTeam();
                  break;
                case 'delete':
                  _confirmDeleteTeam();
                  break;
              }
            },
            itemBuilder: (_) => [
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
              if (_permissions.canInviteMembers)
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Invite Member'),
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
              if (!isOwner) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app_rounded,
                        size: 18,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Leave Team',
                        style: TextStyle(color: Colors.orange.shade400),
                      ),
                    ],
                  ),
                ),
              ],
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
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const TaskCreationDialog(),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Task',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (!_permissions.canViewTasks) return _NoAccessView();

          if (db.currentTasks.isEmpty) {
            return _EmptyStateView(
              canCreate: _permissions.canCreateTasks,
              isMemberRole: _userRole.toLowerCase() == 'member',
              onCreate: () => showDialog(
                context: context,
                builder: (_) => const TaskCreationDialog(),
              ),
            );
          }

          // ── Centre + cap width of the scrollable content ────────────────
          return ResponsiveBody(
            child: RefreshIndicator(
              onRefresh: db.refreshData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _RoleCard(userRole: _userRole),
                  const SizedBox(height: 16),
                  const DashboardStats(),
                  const SizedBox(height: 20),
                  _TasksSection(
                    db: db,
                    isDark: isDark,
                    userRole: _userRole,
                    permissions: _permissions,
                    onNoPermission: _showNoPermissionDialog,
                  ),
                ],
              ),
            ),
          );
        },
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
          "You don't have permission to $action.\n\nOnly owners and admins can do this.",
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
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String userRole;
  const _RoleCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: RoleHelpers.gradient(userRole),
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
            child: Icon(
              RoleHelpers.icon(userRole),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are a ${RoleHelpers.displayName(userRole)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  RoleHelpers.description(userRole),
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
}

class _TasksSection extends StatelessWidget {
  final TaskDatabase db;
  final bool isDark;
  final String userRole;
  final TeamPermissions permissions;
  final void Function(String) onNoPermission;

  const _TasksSection({
    required this.db,
    required this.isDark,
    required this.userRole,
    required this.permissions,
    required this.onNoPermission,
  });

  @override
  Widget build(BuildContext context) {
    final active = db.activeTasks;
    final completed = db.completedTasks;
    final isMember = userRole.toLowerCase() == 'member';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMember)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(
                0xFFDBEAFE,
              ).withValues(alpha: isDark ? 0.18 : 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'You can only view and complete tasks assigned to you. '
              'Owners/admins manage creation, deletion, and assignment.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        if (active.isNotEmpty) ...[
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
                  'Active Tasks (${active.length})',
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
          ...active.map((task) {
            final canEdit = permissions.canEditTask(
              task.assignedBy?.id ?? '',
              db.userId ?? '',
            );
            final canDelete = permissions.canDeleteTask(
              task.assignedBy?.id ?? '',
              db.userId ?? '',
            );
            return TaskTile(
              key: ValueKey(task.id),
              task: task,
              onToggle: (v) async {
                if (!permissions.canCompleteTasks) {
                  ErrorHandler.showSnackBarError(
                    context,
                    'You do not have permission to complete tasks',
                  );
                  return;
                }
                try {
                  await db.completeTask(task.id, v);
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.showSnackBarError(context, e);
                  }
                  rethrow;
                }
              },
              onEdit: canEdit
                  ? () => showEditTaskDialog(context, task, db)
                  : () => onNoPermission('edit'),
              onDelete: canDelete
                  ? () => showDeleteTaskDialog(context, task, db)
                  : () => onNoPermission('delete'),
            );
          }),
        ],
        if (completed.isNotEmpty) ...[
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
                  'Completed Today (${completed.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFE8E6FF)
                        : const Color(0xFF1C1B3A),
                  ),
                ),
                subtitle: Text(
                  completed.length == 1
                      ? 'Great work! 🎉'
                      : 'Amazing! ${completed.length} done! 🎉',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 12,
                  ),
                ),
                children: completed
                    .map(
                      (task) => TaskTile(
                        key: ValueKey('completed_${task.id}'),
                        task: task,
                        onToggle: (v) async {
                          if (!permissions.canCompleteTasks) {
                            ErrorHandler.showSnackBarError(
                              context,
                              'No permission to modify task completion',
                            );
                            return;
                          }
                          try {
                            await db.completeTask(task.id, v);
                          } catch (e) {
                            if (context.mounted) {
                              ErrorHandler.showSnackBarError(context, e);
                            }
                            rethrow;
                          }
                        },
                        onEdit: () => onNoPermission('edit a completed task'),
                        onDelete: () => onNoPermission('delete'),
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
}

class _EmptyStateView extends StatelessWidget {
  final bool canCreate;
  final bool isMemberRole;
  final VoidCallback onCreate;

  const _EmptyStateView({
    required this.canCreate,
    required this.isMemberRole,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
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
              canCreate
                  ? 'Create the first task for your team'
                  : 'Tasks assigned to you by admins will appear here',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B66A3), fontSize: 14),
            ),
            if (canCreate) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoAccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            "You don't have permission to view team tasks",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B66A3)),
          ),
        ],
      ),
    );
  }
}
