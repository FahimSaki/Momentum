import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:momentum/blocs/team_state.dart';
import 'package:momentum/database/local_cache_service.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/services/team_service.dart';
import 'package:momentum/utils/network_utils.dart';

/// Owns userTeams, pendingInvitations, and selectedTeam.
///
/// Same behavior as the TeamBloc this replaces — every event handler's
/// body moved directly into a public method, Completer wrappers dropped
/// since a plain async method is already awaitable on its own. Team
/// switching itself still works exactly the same way: TaskCubit listens
/// to this cubit's stream directly, which Cubit exposes identically to
/// Bloc.
class TeamCubit extends Cubit<TeamState> {
  final Logger _logger = Logger();
  final LocalCacheService _cache = LocalCacheService();
  TeamService? _service;

  TeamCubit() : super(const TeamState());

  void setToken(String jwtToken) {
    _service = TeamService(jwtToken: jwtToken);
  }

  /// Reloads both userTeams and pendingInvitations together — used for
  /// full init. Renamed from refreshAllAndWait(): the "AndWait" suffix
  /// only ever signaled "this one bridges to a real Future," which every
  /// Cubit method already does, so it's dropped.
  Future<void> loadTeamsAndInvitations() async {
    await _loadUserTeams();
    await _loadPendingInvitations();
  }

  /// Reloads only pendingInvitations — used for the lighter per-poll
  /// refresh, preserving the original asymmetry (a plain refresh never
  /// reloaded the team list, only invitations). Renamed from
  /// refreshPendingInvitationsAndWait() for the same reason as above.
  Future<void> loadPendingInvitations() async {
    await _loadPendingInvitations();
  }

  Future<void> _loadUserTeams() async {
    try {
      final teams = await _service?.getUserTeams() ?? [];
      emit(state.copyWith(userTeams: teams, isOffline: false));
      await _cache.saveTeams(teams);
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        _logger.w('Offline — showing cached teams');
        final cached = await _cache.loadTeams();
        emit(state.copyWith(userTeams: cached, isOffline: true));
      } else {
        _logger.e('Error loading user teams', error: e, stackTrace: stackTrace);
      }
    }
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final invitations = await _service?.getPendingInvitations() ?? [];
      emit(state.copyWith(pendingInvitations: invitations));
    } catch (e, stackTrace) {
      _logger.e(
        'Error loading pending invitations',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Replaces `context.read<TeamBloc>().add(TeamSelected(team))`.
  void selectTeam(Team? team) {
    emit(
      TeamState(
        userTeams: state.userTeams,
        pendingInvitations: state.pendingInvitations,
        selectedTeam: team,
        isOffline: state.isOffline,
      ),
    );
  }

  Future<Team> createTeam(String name, {String? description}) async {
    try {
      final team = await _service!.createTeam(name, description: description);
      emit(state.copyWith(userTeams: [...state.userTeams, team]));
      return team;
    } catch (e, stackTrace) {
      _logger.e('Error creating team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Team> getTeamDetails(String teamId) async {
    try {
      return await _service!.getTeamDetails(teamId);
    } catch (e, stackTrace) {
      _logger.e(
        'Error fetching team details',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateTeamSettings(
    String teamId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _service!.updateTeamSettings(teamId, settings);
      await _loadUserTeams();
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating team settings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _service!.deleteTeam(teamId);
      final updatedTeams = state.userTeams
          .where((t) => t.id != teamId)
          .toList();
      final wasSelected = state.selectedTeam?.id == teamId;
      emit(
        TeamState(
          userTeams: updatedTeams,
          pendingInvitations: state.pendingInvitations,
          selectedTeam: wasSelected ? null : state.selectedTeam,
          isOffline: state.isOffline,
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('Error deleting team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> leaveTeam(String teamId) async {
    try {
      await _service!.leaveTeam(teamId);
      final updatedTeams = state.userTeams
          .where((t) => t.id != teamId)
          .toList();
      final wasSelected = state.selectedTeam?.id == teamId;
      emit(
        TeamState(
          userTeams: updatedTeams,
          pendingInvitations: state.pendingInvitations,
          selectedTeam: wasSelected ? null : state.selectedTeam,
          isOffline: state.isOffline,
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('Error leaving team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeTeamMember(String teamId, String memberId) async {
    try {
      await _service!.removeTeamMember(teamId, memberId);
      await _loadUserTeams();
      if (state.selectedTeam?.id == teamId) {
        final updated = state.userTeams
            .where((t) => t.id == teamId)
            .firstOrNull;
        if (updated != null) {
          emit(
            TeamState(
              userTeams: state.userTeams,
              pendingInvitations: state.pendingInvitations,
              selectedTeam: updated,
              isOffline: state.isOffline,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error removing team member', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> inviteToTeam({
    required String teamId,
    String? email,
    String? inviteId,
    String role = 'member',
    String? message,
  }) async {
    try {
      await _service!.inviteToTeam(
        teamId: teamId,
        email: email,
        inviteId: inviteId,
        role: role,
        message: message,
      );
    } catch (e, stackTrace) {
      _logger.e('Error inviting to team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateTeamMemberRole(
    String teamId,
    String memberId,
    String role,
  ) async {
    try {
      await _service!.updateTeamMemberRole(teamId, memberId, role);
      await _loadUserTeams();
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating team member role',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> respondToInvitation(String invitationId, bool accept) async {
    try {
      final response = accept ? 'accepted' : 'declined';
      await _service!.respondToInvitation(invitationId, response);
      final updatedInvitations = state.pendingInvitations
          .where((inv) => inv.id != invitationId)
          .toList();
      emit(state.copyWith(pendingInvitations: updatedInvitations));
      if (accept) await _loadUserTeams();
    } catch (e, stackTrace) {
      _logger.e(
        'Error responding to invitation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Replaces `context.read<TeamBloc>().add(const TeamsCleared())`. Only
  /// ever called internally by TaskCubit.clearData() — not a
  /// consumer-facing change.
  void clear() {
    emit(const TeamState());
  }
}
