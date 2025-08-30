import 'package:momentum/models/user_notification_settings.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String? bio;
  final String timezone;
  final List<String> teams;
  final UserNotificationSettings notificationSettings;
  final DateTime lastLoginAt;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.bio,
    this.timezone = 'UTC',
    this.teams = const [],
    required this.notificationSettings,
    required this.lastLoginAt,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      email: json['email'],
      name: json['name'],
      avatar: json['avatar'],
      bio: json['bio'],
      timezone: json['timezone'] ?? 'UTC',
      teams:
          (json['teams'] as List<dynamic>?)
              ?.map((teamId) => teamId.toString())
              .toList() ??
          [],
      notificationSettings: UserNotificationSettings.fromJson(
        json['notificationSettings'] ?? {},
      ),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'bio': bio,
      'timezone': timezone,
      'teams': teams,
      'notificationSettings': notificationSettings.toJson(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory User.empty() {
    return User(
      id: '',
      email: '',
      name: '',
      notificationSettings: UserNotificationSettings(),
      lastLoginAt: DateTime.now(),
    );
  }

  String get initials {
    if (name.isEmpty) return '';
    final names = name.split(' ');
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    } else {
      return '${names[0].substring(0, 1)}${names.last.substring(0, 1)}'
          .toUpperCase();
    }
  }
}
