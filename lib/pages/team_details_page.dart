import 'package:flutter/material.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/pages/team_settings_page.dart';
import 'package:momentum/pages/user_search_page.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';

class TeamDetailsPage extends StatefulWidget {
  final Team team;
  const TeamDetailsPage({super.key, required this.team});

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  Team? _team;
  bool _isLoadingTeam = true;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _loadLatestTeam();
  }

  Future<void> _loadLatestTeam() async {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    try {
      final freshTeam = await db.getTeamDetails(widget.team.id);
      if (!mounted) return;
      setState(() {
        _team = freshTeam;
        _isLoadingTeam = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingTeam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<TaskDatabase>(context, listen: false);
    final team = _team ?? widget.team;
    final isOwnerOrAdmin =
        team.isAdmin(db.userId ?? '') || team.isOwner(db.userId ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          if (isOwnerOrAdmin)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Team Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamSettingsPage(team: team)),
              ),
            ),
          if (isOwnerOrAdmin)
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'invite') _showInviteDialog();
                if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamSettingsPage(team: team),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
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
                const PopupMenuItem(
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
      body: _isLoadingTeam
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Team info card
                _buildTeamInfoCard(team, isDark),
                const SizedBox(height: 16),

                // Members section header
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

                // Members list
                ...team.members.map(
                  (member) => _buildMemberCard(member, isDark),
                ),
                const SizedBox(height: 24),

                // Quick actions
                if (isOwnerOrAdmin) ...[
                  _buildActionButton(
                    icon: Icons.person_add_rounded,
                    label: 'Invite Member',
                    color: const Color(0xFF6366F1),
                    onTap: _showInviteDialog,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.settings_rounded,
                    label: 'Team Settings',
                    color: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamSettingsPage(team: team),
                      ),
                    ),
                    isDark: isDark,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildTeamInfoCard(Team team, bool isDark) {
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
                if (team.description != null && team.description!.isNotEmpty)
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
                Row(
                  children: [
                    _statPill(
                      '${team.members.length}',
                      'members',
                      Colors.white,
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

  Widget _statPill(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(TeamMember member, bool isDark) {
    final roleColor = _roleColor(member.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1929) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2C44) : const Color(0xFFEDE9FE),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            member.user.initials,
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          member.user.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          member.user.email,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF9B99C8) : const Color(0xFF6B66A3),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            member.role.toUpperCase(),
            style: TextStyle(
              color: roleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
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

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  void _showInviteDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserSearchPage(teamId: widget.team.id, teamName: widget.team.name),
      ),
    );
  }
}
