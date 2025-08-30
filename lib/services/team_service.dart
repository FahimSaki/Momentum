import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:momentum/constants/api_base_url.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_invitation.dart';
import 'package:logger/logger.dart';

class TeamService {
  final Logger _logger = Logger();
  final String jwtToken;

  TeamService({required this.jwtToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };

  // Create a new team
  Future<Team> createTeam(String name, {String? description}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams'),
        headers: _headers,
        body: json.encode({'name': name, 'description': description}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Team.fromJson(data['team']);
      } else {
        _logger.e('Error creating team: ${response.body}');
        throw Exception('Failed to create team: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get user's teams
  Future<List<Team>> getUserTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((team) => Team.fromJson(team)).toList();
      } else {
        _logger.e('Error fetching teams: ${response.body}');
        throw Exception('Failed to fetch teams');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching teams', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get team details
  Future<Team> getTeamDetails(String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams/$teamId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Team.fromJson(data);
      } else {
        _logger.e('Error fetching team details: ${response.body}');
        throw Exception('Failed to fetch team details');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error fetching team details',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Invite user to team
  Future<void> inviteToTeam({
    required String teamId,
    required String email,
    String role = 'member',
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams/$teamId/invite'),
        headers: _headers,
        body: json.encode({'email': email, 'role': role, 'message': message}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to invite user');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error inviting user to team',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Get pending invitations
  Future<List<TeamInvitation>> getPendingInvitations() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/teams/invitations/pending'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((invitation) => TeamInvitation.fromJson(invitation))
            .toList();
      } else {
        _logger.e('Error fetching invitations: ${response.body}');
        throw Exception('Failed to fetch invitations');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching invitations', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Respond to team invitation
  Future<void> respondToInvitation(String invitationId, String response) async {
    try {
      final httpResponse = await http.put(
        Uri.parse('$apiBaseUrl/teams/invitations/$invitationId/respond'),
        headers: _headers,
        body: json.encode({'response': response}),
      );

      if (httpResponse.statusCode != 200) {
        final errorData = json.decode(httpResponse.body);
        throw Exception(
          errorData['message'] ?? 'Failed to respond to invitation',
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error responding to invitation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Update team settings
  Future<void> updateTeamSettings(
    String teamId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/teams/$teamId/settings'),
        headers: _headers,
        body: json.encode({'settings': settings}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to update team settings',
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error updating team settings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Remove team member
  Future<void> removeTeamMember(String teamId, String memberId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/teams/$teamId/members/$memberId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to remove team member');
      }
    } catch (e, stackTrace) {
      _logger.e('Error removing team member', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Leave team
  Future<void> leaveTeam(String teamId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams/$teamId/leave'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to leave team');
      }
    } catch (e, stackTrace) {
      _logger.e('Error leaving team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Delete team
  Future<void> deleteTeam(String teamId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/teams/$teamId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete team');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
