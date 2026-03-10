import 'package:momentum/models/user.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/profile_visibility.dart';
import 'package:momentum/models/user_notification_settings.dart';
import 'package:momentum/models/team_settings.dart';
import 'package:momentum/models/notification_settings.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class AppNotification {
  final String id;
  final User? recipient;
  final User? sender;
  final Team? team;
  final Task? task;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    this.recipient,
    this.sender,
    this.team,
    this.task,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      recipient: _parseOptionalUser(json['recipient']),
      sender: _parseOptionalUser(json['sender']),
      team: _parseOptionalTeam(json['team']),
      task: _parseOptionalTask(json['task']),
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? _parseDateTime(json['readAt']) : null,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  // Parse optional user (returns null if unpopulated or missing)
  static User? _parseOptionalUser(dynamic userData) {
    if (userData == null) return null;

    // If it's a String (ObjectId), create minimal User
    if (userData is String) {
      return User(
        id: userData,
        name: 'Unknown User',
        email: '',
        notificationSettings: UserNotificationSettings(),
        lastLoginAt: DateTime.now(),
        inviteId: '',
        profileVisibility: ProfileVisibility(),
      );
    }

    // If it's a Map, try to parse
    if (userData is Map<String, dynamic>) {
      try {
        return User.fromJson(userData);
      } catch (e) {
        _logger.e('Error parsing notification user: $e');
        return User(
          id:
              userData['_id']?.toString() ??
              userData['id']?.toString() ??
              'unknown',
          name: userData['name']?.toString() ?? 'Unknown User',
          email: userData['email']?.toString() ?? '',
          avatar: userData['avatar']?.toString(),
          notificationSettings: UserNotificationSettings(),
          lastLoginAt: DateTime.now(),
          inviteId: '',
          profileVisibility: ProfileVisibility(),
        );
      }
    }

    return null;
  }

  // Parse optional team (returns null if unpopulated or missing)
  static Team? _parseOptionalTeam(dynamic teamData) {
    if (teamData == null) return null;

    // If it's a String (ObjectId), create minimal Team
    if (teamData is String) {
      return Team(
        id: teamData,
        name: 'Unknown Team',
        description: '',
        owner: User(
          id: 'unknown',
          name: 'Unknown',
          email: '',
          notificationSettings: UserNotificationSettings(),
          lastLoginAt: DateTime.now(),
          inviteId: '',
          profileVisibility: ProfileVisibility(),
        ),
        members: [],
        settings: TeamSettings(notificationSettings: NotificationSettings()),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // If it's a Map, try to parse
    if (teamData is Map<String, dynamic>) {
      try {
        return Team.fromJson(teamData);
      } catch (e) {
        _logger.e('Error parsing notification team: $e');
        return Team(
          id:
              teamData['_id']?.toString() ??
              teamData['id']?.toString() ??
              'unknown',
          name: teamData['name']?.toString() ?? 'Unknown Team',
          description: teamData['description']?.toString() ?? '',
          owner: User(
            id: 'unknown',
            name: 'Unknown',
            email: '',
            notificationSettings: UserNotificationSettings(),
            lastLoginAt: DateTime.now(),
            inviteId: '',
            profileVisibility: ProfileVisibility(),
          ),
          members: [],
          settings: TeamSettings(notificationSettings: NotificationSettings()),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    return null;
  }

  // Parse optional task (returns null if unpopulated or missing)
  static Task? _parseOptionalTask(dynamic taskData) {
    if (taskData == null) return null;

    // If it's a String (ObjectId), return null (Task requires too many fields)
    if (taskData is String) {
      return null;
    }

    // If it's a Map, try to parse
    if (taskData is Map<String, dynamic>) {
      try {
        return Task.fromJson(taskData);
      } catch (e) {
        _logger.e('⚠️ Error parsing notification task: $e');
        return null;
      }
    }

    return null;
  }

  // Safe DateTime parsing
  static DateTime _parseDateTime(dynamic dateData) {
    if (dateData == null) return DateTime.now();

    try {
      if (dateData is String) return DateTime.parse(dateData);
      if (dateData is DateTime) return dateData;
    } catch (e) {
      _logger.e('Error parsing notification date: $e');
    }
    return DateTime.now();
  }

  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
