import 'package:flutter/material.dart';
import 'package:momentum/utils/role_helpers.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/pages/team_settings_page.dart';
import 'package:momentum/pages/user_search_page.dart';
import 'package:provider/provider.dart';

class TeamDetailsPage extends StatefulWidget {
  final Team team;
  const TeamDetailsPage({super.key, required this.team});

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  Team? _team;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      final fresh = await db.getTeamDetails(widget.team.id);
      if (mounted) {
        setState(() {
          _team = fresh;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLeaveTeam() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    final team = _team ?? widget.team;

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
          'Are you sure you want to leave "${team.name}"?\n\n'
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
            content: Text('You have left "${team.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to leave: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveMember(TeamMember member) async {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    final team = _team ?? widget.team;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_remove, color: Colors.red),
            SizedBox(width: 10),
            Text('Remove Member'),
          ],
        ),
        content: Text(
          'Remove "${member.user.name}" from "${team.name}"?\n\n'
          'They will lose access to all team tasks immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await db.removeTeamMember(widget.team.id, member.user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.user.name} has been removed from the team'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the displayed team
        await _loadLatest();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove: ${e.toString().replaceFirst('Exception: ', '')}',
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
    final myUserId = db.userId ?? '';
    final isOwner = team.isOwner(myUserId);
    final isAdmin = team.getMember(myUserId)?.role == 'admin';
    final canManage = isOwner || isAdmin;
    // A member who is not owner can leave
    final canLeave = !isOwner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamSettingsPage(team: team)),
              ),
            ),
          if (canManage)
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (v) {
                if (v == 'invite') _showInvite();
                if (v == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamSettingsPage(team: team),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Invite Member'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Team Settings'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TeamInfoCard(team: team),
                const SizedBox(height: 16),

                // Members header
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
                        'Members (${team.members.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Member list with remove option for owners/admins
                ...team.members.map(
                  (m) => _MemberCard(
                    member: m,
                    isDark: isDark,
                    myUserId: myUserId,
                    isOwner: isOwner,
                    isAdmin: isAdmin,
                    onRemove:
                        canManage && m.role != 'owner' && m.user.id != myUserId
                        ? () => _confirmRemoveMember(m)
                        : null,
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons — invite only for owners/admins
                if (canManage) ...[
                  _ActionButton(
                    icon: Icons.person_add_rounded,
                    label: 'Invite Member',
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                    onTap: _showInvite,
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.settings_rounded,
                    label: 'Team Settings',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamSettingsPage(team: team),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Leave team — available to all non-owners
                if (canLeave) ...[
                  _ActionButton(
                    icon: Icons.exit_to_app_rounded,
                    label: 'Leave Team',
                    color: Colors.orange,
                    isDark: isDark,
                    onTap: _confirmLeaveTeam,
                  ),
                ],
              ],
            ),
    );
  }

  void _showInvite() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          UserSearchPage(teamId: widget.team.id, teamName: widget.team.name),
    ),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────

class _TeamInfoCard extends StatelessWidget {
  final Team team;
  const _TeamInfoCard({required this.team});

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
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      team.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${team.members.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'members',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _MemberCard extends StatelessWidget {
  final TeamMember member;
  final bool isDark;
  final String myUserId;
  final bool isOwner;
  final bool isAdmin;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.member,
    required this.isDark,
    required this.myUserId,
    required this.isOwner,
    required this.isAdmin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = RoleHelpers.color(member.role);
    final isMe = member.user.id == myUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1929) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? const Color(0xFF6366F1).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE)),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            member.user.initials,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.user.name + (isMe ? ' (You)' : ''),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          member.user.email,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF9B99C8) : const Color(0xFF6B66A3),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoleBadge(role: member.role),
            // Show remove button for owners/admins (but not for the owner themselves,
            // and not for yourself)
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.person_remove_rounded,
                  size: 20,
                  color: Colors.red,
                ),
                tooltip: 'Remove member',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1929) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF5A587A) : const Color(0xFFB0ADDB),
            ),
          ],
        ),
      ),
    );
  }
}
