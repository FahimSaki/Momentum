import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/pages/create_team_page.dart';
import 'package:momentum/pages/team_invitations_page.dart';
import 'package:provider/provider.dart';

class TeamSelectionPage extends StatefulWidget {
  const TeamSelectionPage({super.key});

  @override
  State<TeamSelectionPage> createState() => _TeamSelectionPageState();
}

class _TeamSelectionPageState extends State<TeamSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Team'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateTeamPage()),
              );
            },
          ),
          Consumer<TaskDatabase>(
            builder: (context, db, _) {
              final hasInvitations = db.pendingInvitations.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TeamInvitationsPage(),
                        ),
                      );
                    },
                  ),
                  if (hasInvitations)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '${db.pendingInvitations.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Personal tasks option
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  title: const Text('Personal Tasks'),
                  subtitle: Text('${db.personalTasks.length} tasks'),
                  trailing: db.selectedTeam == null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    db.selectTeam(null);
                    Navigator.pop(context);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Teams section
              if (db.userTeams.isNotEmpty) ...[
                Text('Teams', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...db.userTeams.map(
                  (team) => Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.group, color: Colors.white),
                      ),
                      title: Text(team.name),
                      subtitle: Text('${team.members.length} members'),
                      trailing: db.selectedTeam?.id == team.id
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        db.selectTeam(team);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No teams yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a team or accept an invitation to get started',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateTeamPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Team'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
