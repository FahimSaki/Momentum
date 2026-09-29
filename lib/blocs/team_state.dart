import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_invitation.dart';

class TeamState {
  final List<Team> userTeams;
  final List<TeamInvitation> pendingInvitations;
  final Team? selectedTeam;
  final bool isOffline;

  // Sentinel used only to detect "selectedTeam was not passed" in copyWith,
  // since `null` itself is a valid, meaningful value for that field (it
  // means "no team selected", i.e. Personal Tasks).
  static const _unset = Object();

  const TeamState({
    this.userTeams = const [],
    this.pendingInvitations = const [],
    this.selectedTeam,
    this.isOffline = false,
  });

  /// Pass `selectedTeam: null` to explicitly clear the selection, or omit
  /// it to leave the current value untouched — the sentinel default below
  /// distinguishes "not passed" from "passed as null", so TeamCubit no
  /// longer needs to construct TeamState directly just to change or clear
  /// the selected team.
  TeamState copyWith({
    List<Team>? userTeams,
    List<TeamInvitation>? pendingInvitations,
    Object? selectedTeam = _unset,
    bool? isOffline,
  }) {
    return TeamState(
      userTeams: userTeams ?? this.userTeams,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      selectedTeam: identical(selectedTeam, _unset)
          ? this.selectedTeam
          : selectedTeam as Team?,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
