import 'package:logger/logger.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/profile_visibility.dart';
import 'package:momentum/models/user_notification_settings.dart';
import 'package:momentum/models/team_settings.dart';
import 'package:momentum/models/notification_settings.dart';

final Logger _logger = Logger();

class TeamInvitation {
  final String id;
  final Team team;
  final User inviter;
  final User invitee;
  final String email;
  final String role;
  final String status;
  final DateTime expiresAt;
  final String? message;
  final DateTime createdAt;

  TeamInvitation({
    required this.id,
    required this.team,
    required this.inviter,
    required this.invitee,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    this.message,
    required this.createdAt,
  });

  factory TeamInvitation.fromJson(Map<String, dynamic> json) {
    return TeamInvitation(
      id: json['_id'] ?? json['id'] ?? '',
      team: _parseTeam(json['team']),
      inviter: _parseUser(json['inviter'], 'Unknown Inviter'),
      invitee: _parseUser(json['invitee'], 'Unknown User'),
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      status: json['status'] ?? 'pending',
      expiresAt: _parseDateTime(json['expiresAt']),
      message: json['message'],
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  // Parse team (handles String, Map, or null)
  static Team _parseTeam(dynamic teamData) {
    if (teamData == null) {
      return _createDefaultTeam('unknown');
    }

    if (teamData is String) {
      return _createDefaultTeam(teamData);
    }

    if (teamData is Map<String, dynamic>) {
      try {
        return Team.fromJson(teamData);
      } catch (e) {
        _logger.e('Error parsing team: $e');
        return _createDefaultTeam(
          teamData['_id']?.toString() ??
              teamData['id']?.toString() ??
              'unknown',
        );
      }
    }

    return _createDefaultTeam('unknown');
  }

  // Parse user (handles String, Map, or null)
  static User _parseUser(dynamic userData, String fallbackName) {
    if (userData == null) {
      return _createDefaultUser('unknown', fallbackName);
    }

    if (userData is String) {
      return _createDefaultUser(userData, fallbackName);
    }

    if (userData is Map<String, dynamic>) {
      try {
        return User.fromJson(userData);
      } catch (e) {
        _logger.e('Error parsing user: $e');
        return _createDefaultUser(
          userData['_id']?.toString() ??
              userData['id']?.toString() ??
              'unknown',
          userData['name']?.toString() ?? fallbackName,
        );
      }
    }

    return _createDefaultUser('unknown', fallbackName);
  }

  // Parse DateTime safely
  static DateTime _parseDateTime(dynamic dateData) {
    if (dateData == null) return DateTime.now();

    try {
      if (dateData is String) return DateTime.parse(dateData);
      if (dateData is DateTime) return dateData;
    } catch (e) {
      _logger.e('Error parsing date: $e');
    }
    return DateTime.now();
  }

  // Create default Team object
  static Team _createDefaultTeam(String id) {
    return Team(
      id: id,
      name: 'Unknown Team',
      description: '',
      owner: _createDefaultUser('unknown', 'Unknown'),
      members: [],
      settings: TeamSettings(notificationSettings: NotificationSettings()),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Create default User object
  static User _createDefaultUser(String id, String name) {
    return User(
      id: id,
      email: '',
      name: name,
      notificationSettings: UserNotificationSettings(),
      lastLoginAt: DateTime.now(),
      inviteId: '',
      profileVisibility: ProfileVisibility(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canRespond => isPending && !isExpired;
}
