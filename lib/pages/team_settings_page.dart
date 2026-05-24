import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:momentum/utils/role_helpers.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class TeamSettingsPage extends StatefulWidget {
  final Team team;
  const TeamSettingsPage({super.key, required this.team});

  @override
  State<TeamSettingsPage> createState() => _TeamSettingsPageState();
}

class _TeamSettingsPageState extends State<TeamSettingsPage> {
  final Logger _logger = Logger();

  Team? _team;
  bool _isLoadingTeam = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUpdatingRoles = false;
  bool _hasChanges = false;

  late bool _allowMemberInvite;
  late bool _taskAutoDelete;
  late bool _notifyTaskAssigned;
  late bool _notifyTaskCompleted;
  late bool _notifyMemberJoined;

  @override
  void initState() {
    super.initState();
    _allowMemberInvite = widget.team.settings.allowMemberInvite;
    _taskAutoDelete = widget.team.settings.taskAutoDelete;
    _notifyTaskAssigned =
        widget.team.settings.notificationSettings.taskAssigned;
    _notifyTaskCompleted =
        widget.team.settings.notificationSettings.taskCompleted;
    _notifyMemberJoined =
        widget.team.settings.notificationSettings.memberJoined;
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      final fresh = await db.getTeamDetails(widget.team.id);
      if (mounted) {
        setState(() {
          _team = fresh;
          _isLoadingTeam = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading team', error: e);
      if (mounted) setState(() => _isLoadingTeam = false);
    }
  }

  void _markChanged() => setState(() => _hasChanges = true);

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.updateTeamSettings(widget.team.id, {
        'allowMemberInvite': _allowMemberInvite,
        'taskAutoDelete': _taskAutoDelete,
        'notificationSettings': {
          'taskAssigned': _notifyTaskAssigned,
          'taskCompleted': _notifyTaskCompleted,
          'memberJoined': _notifyMemberJoined,
        },
      });
      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Settings saved successfully'),
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
    } catch (e) {
      _logger.e('Error saving settings', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTeam() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (!widget.team.isOwner(db.userId ?? '')) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE53E3E),
              size: 24,
            ),
            SizedBox(width: 10),
            Text('Delete Team', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re about to permanently delete "${widget.team.name}".',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF991B1B),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Remove all team members',
                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                  ),
                  Text(
                    '• Delete all team tasks',
                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                  ),
                  Text(
                    '• Erase all team history',
                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
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
            child: const Text('Delete Team'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await db.deleteTeam(widget.team.id);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      _logger.e('Error deleting team', error: e);
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting team: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    final team = _team ?? widget.team;
    final isOwner = team.isOwner(db.userId ?? '');
    final isAdmin = team.getMember(db.userId ?? '')?.role == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Settings'),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton(
                      onPressed: _saveSettings,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Save'),
                    ),
            ),
        ],
      ),
      body: _isLoadingTeam
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(team: team),
                const SizedBox(height: 20),
                _SettingsSection(
                  icon: Icons.group_work_rounded,
                  iconBg: const Color(0xFF6366F1),
                  title: 'Collaboration',
                  isDark: isDark,
                  children: [
                    _ToggleTile(
                      title: 'Allow Member Invites',
                      subtitle: 'Members can invite others to this team',
                      value: _allowMemberInvite,
                      isDark: isDark,
                      onChanged: (v) {
                        setState(() => _allowMemberInvite = v);
                        _markChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.task_alt_rounded,
                  iconBg: const Color(0xFF22C55E),
                  title: 'Tasks',
                  isDark: isDark,
                  children: [
                    _ToggleTile(
                      title: 'Auto-Delete Completed Tasks',
                      subtitle:
                          'Tasks are cleared at midnight after completion',
                      value: _taskAutoDelete,
                      isDark: isDark,
                      onChanged: (v) {
                        setState(() => _taskAutoDelete = v);
                        _markChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.notifications_rounded,
                  iconBg: const Color(0xFFF59E0B),
                  title: 'Notifications',
                  isDark: isDark,
                  children: [
                    _ToggleTile(
                      title: 'Task Assigned',
                      subtitle: 'Alert when a task is assigned to a member',
                      value: _notifyTaskAssigned,
                      isDark: isDark,
                      onChanged: (v) {
                        setState(() => _notifyTaskAssigned = v);
                        _markChanged();
                      },
                    ),
                    _Divider(isDark: isDark),
                    _ToggleTile(
                      title: 'Task Completed',
                      subtitle: 'Alert when a member completes a task',
                      value: _notifyTaskCompleted,
                      isDark: isDark,
                      onChanged: (v) {
                        setState(() => _notifyTaskCompleted = v);
                        _markChanged();
                      },
                    ),
                    _Divider(isDark: isDark),
                    _ToggleTile(
                      title: 'Member Joined',
                      subtitle: 'Alert when someone accepts an invitation',
                      value: _notifyMemberJoined,
                      isDark: isDark,
                      onChanged: (v) {
                        setState(() => _notifyMemberJoined = v);
                        _markChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.people_alt_rounded,
                  iconBg: const Color(0xFF3B82F6),
                  title: 'Members',
                  isDark: isDark,
                  children: team.members
                      .map(
                        (m) => _MemberTile(
                          member: m,
                          isDark: isDark,
                          isOwner: isOwner,
                          isAdmin: isAdmin,
                          isUpdating: _isUpdatingRoles,
                          onUpdateRole: (memberId, role) =>
                              _updateRole(memberId, role),
                        ),
                      )
                      .toList(),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 28),
                  _DangerZone(
                    isDark: isDark,
                    isDeleting: _isDeleting,
                    onDelete: _deleteTeam,
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Future<void> _updateRole(String memberId, String role) async {
    if (_isUpdatingRoles) return;
    setState(() => _isUpdatingRoles = true);
    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.updateTeamMemberRole(widget.team.id, memberId, role);
      final fresh = await db.getTeamDetails(widget.team.id);
      if (mounted) setState(() => _team = fresh);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to ${role.toUpperCase()}'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update role: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingRoles = false);
    }
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Team team;
  const _HeaderCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.group_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (team.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      team.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${team.members.length} members',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconBg, size: 17),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
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
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFE8E6FF)
                        : const Color(0xFF1C1B3A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9B99C8)
                        : const Color(0xFF6B66A3),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF6366F1),
            thumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final TeamMember member;
  final bool isDark;
  final bool isOwner;
  final bool isAdmin;
  final bool isUpdating;
  final void Function(String memberId, String role) onUpdateRole;

  const _MemberTile({
    required this.member,
    required this.isDark,
    required this.isOwner,
    required this.isAdmin,
    required this.isUpdating,
    required this.onUpdateRole,
  });

  @override
  Widget build(BuildContext context) {
    final canPromote = (isOwner || isAdmin) && member.role == 'member';
    final canDemote = isOwner && member.role == 'admin';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: RoleHelpers.color(member.role).withValues(alpha: 0.15),
        child: Text(
          member.user.initials,
          style: TextStyle(
            color: RoleHelpers.color(member.role),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        member.user.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
      ),
      subtitle: Text(
        member.user.email,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF9B99C8) : const Color(0xFF6B66A3),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          RoleBadge(role: member.role),
          if (canPromote)
            OutlinedButton.icon(
              onPressed: isUpdating
                  ? null
                  : () => onUpdateRole(member.user.id, 'admin'),
              icon: const Icon(Icons.arrow_upward_rounded, size: 14),
              label: const Text('Promote'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          if (canDemote)
            OutlinedButton.icon(
              onPressed: isUpdating
                  ? null
                  : () => onUpdateRole(member.user.id, 'member'),
              icon: const Icon(Icons.arrow_downward_rounded, size: 14),
              label: const Text('Demote'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final bool isDark;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DangerZone({
    required this.isDark,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE53E3E),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFFE53E3E),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFCA5A5)),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFE53E3E),
                size: 20,
              ),
            ),
            title: const Text(
              'Delete Team',
              style: TextStyle(
                color: Color(0xFFE53E3E),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Permanently delete this team and all its data',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9B99C8)
                    : const Color(0xFF6B66A3),
              ),
            ),
            trailing: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE53E3E),
                    ),
                  )
                : const Icon(Icons.chevron_right, color: Color(0xFFE53E3E)),
            onTap: isDeleting ? null : onDelete,
          ),
        ],
      ),
    );
  }
}
