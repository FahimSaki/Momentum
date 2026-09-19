import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_invitation.dart';

class TeamState {
  final List<Team> userTeams;
  final List<TeamInvitation> pendingInvitations;
  final Team? selectedTeam;
  final bool isOffline;

  const TeamState({
    this.userTeams = const [],
    this.pendingInvitations = const [],
    this.selectedTeam,
    this.isOffline = false,
  });

  /// Never changes selectedTeam — always carries the current value
  /// forward. The handful of handlers that do need to change it (accept/
  /// deliberately clear it) construct a TeamState directly instead, to
  /// avoid the usual copyWith-can't-null-a-field problem.
  TeamState copyWith({
    List<Team>? userTeams,
    List<TeamInvitation>? pendingInvitations,
    bool? isOffline,
  }) {
    return TeamState(
      userTeams: userTeams ?? this.userTeams,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      selectedTeam: selectedTeam,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
