import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Invitations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (db.pendingInvitations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No pending invitations'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: db.pendingInvitations.length,
            itemBuilder: (context, index) {
              final invitation = db.pendingInvitations[index];
              return _InvitationCard(
                invitation: invitation,
                onAccept: () =>
                    _handleInvitation(context, db, invitation, true),
                onDecline: () =>
                    _handleInvitation(context, db, invitation, false),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleInvitation(
    BuildContext context,
    TaskDatabase db,
    TeamInvitation invitation,
    bool accept,
  ) async {
    try {
      await db.respondToInvitation(invitation.id, accept);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Invitation accepted! Welcome to ${invitation.team.name}!'
                  : 'Invitation declined',
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _InvitationCard extends StatelessWidget {
  final TeamInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.team.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (invitation.team.description != null)
                        Text(
                          invitation.team.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Invited by ${invitation.inviter.name}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.security, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Role: ${invitation.role}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),

            if (invitation.message != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(invitation.message!),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
