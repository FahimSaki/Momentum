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
