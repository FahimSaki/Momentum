import 'dart:async';
import 'dart:io';

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
      _logger.i('Attempting to create team: $name');

      final requestBody = {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      };

      _logger.d('Team creation request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/teams'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timeout - please try again'),
          );

      _logger.i('Team creation response status: ${response.statusCode}');
      _logger.d('Team creation response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final team = Team.fromJson(data['team']);
        _logger.i('Team created successfully: ${team.id}');
        return team;
      } else {
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? 'Failed to create team';

          if (errorData['errors'] is List) {
            errorMessage = (errorData['errors'] as List).join(', ');
          }
        } catch (e) {
          errorMessage = 'Failed to create team: ${response.body}';
        }

        _logger.e('Team creation failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      _logger.e('Network error during team creation: $e');
      throw Exception('Network error - please check your internet connection');
    } on TimeoutException catch (e) {
      _logger.e('Timeout during team creation: $e');
      throw Exception('Request timeout - please try again');
    } on FormatException catch (e) {
      _logger.e('JSON parsing error during team creation: $e');
      throw Exception('Server response error - please try again');
    } catch (e) {
      _logger.e('Unexpected team creation error: $e');
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
  Future inviteToTeam({
    required String teamId,
    String? email,
    String? inviteId,
    String role = 'member',
    String? message,
  }) async {
    try {
      final requestBody = {'role': role};

      // Add email or inviteId based on what's provided
      if (email != null) {
        requestBody['email'] = email;
      }
      if (inviteId != null) {
        requestBody['inviteId'] = inviteId;
      }
      if (message != null) {
        requestBody['message'] = message;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/teams/$teamId/invite'),
        headers: _headers,
        body: json.encode(requestBody),
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
