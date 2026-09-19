import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/blocs/task_state.dart';
import 'package:momentum/blocs/team_cubit.dart';
import 'package:momentum/blocs/team_state.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/pages/create_team_page.dart';
import 'package:momentum/pages/home_page.dart';
import 'package:momentum/pages/team_home_page.dart';
import 'package:momentum/pages/team_invitations_page.dart';
import 'package:momentum/pages/team_details_page.dart';

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
          BlocBuilder<TeamCubit, TeamState>(
            builder: (context, state) {
              final hasInvitations = state.pendingInvitations.isNotEmpty;
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
                          '${state.pendingInvitations.length}',
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
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, taskState) {
          return BlocBuilder<TeamCubit, TeamState>(
            builder: (context, teamState) {
              return ResponsiveBody(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.groups_2,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pick a workspace to switch context quickly.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

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
                        subtitle: Text(
                          '${taskState.personalTasks.length} tasks',
                        ),
                        trailing: teamState.selectedTeam == null
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          context.read<TeamCubit>().selectTeam(null);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomePage(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (teamState.userTeams.isNotEmpty) ...[
                      Text(
                        'Teams',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ...teamState.userTeams.map(
                        (team) => Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.group,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(team.name),
                            subtitle: Text('${team.members.length} members'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (teamState.selectedTeam?.id == team.id)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TeamDetailsPage(team: team),
                                      ),
                                    );
                                  },
                                  tooltip: 'Team Details',
                                ),
                              ],
                            ),
                            onTap: () {
                              context.read<TeamCubit>().selectTeam(team);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeamHomePage(team: team),
                                ),
                              );
                            },
                            onLongPress: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeamDetailsPage(team: team),
                                ),
                              );
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
                                    builder: (context) =>
                                        const CreateTeamPage(),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
