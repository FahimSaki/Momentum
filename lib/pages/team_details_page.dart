import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team.dart';
import 'package:provider/provider.dart';

class TeamDetailsPage extends StatefulWidget {
  final Team team;

  const TeamDetailsPage({super.key, required this.team});

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.person_add),
                    SizedBox(width: 8),
                    Text('Invite Member'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Team Settings'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'invite':
                  _showInviteDialog();
                  break;
                case 'settings':
                  _showSettingsDialog();
                  break;
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Team info card
          Card(
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
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.group,
                          color: Colors.blue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.team.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (widget.team.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.team.description!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${widget.team.members.length} members',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Members section
          Text('Members', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          ...widget.team.members.map(
            (member) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Text(
                    member.user.initials,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(member.user.name),
                subtitle: Text(member.user.email),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(member.role).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.role.toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(member.role),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Team Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _inviteController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _inviteController.clear();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _sendInvitation(),
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    // Implementation for team settings
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Settings'),
        content: const Text('Team settings coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation() async {
    final email = _inviteController.text.trim();
    if (email.isEmpty) return;

    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.inviteToTeam(teamId: widget.team.id, email: email);

      if (mounted) {
        Navigator.pop(context);
        _inviteController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending invitation: $e')));
      }
    }
  }
}
