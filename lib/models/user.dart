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
      // Handle both _id and id formats from backend
      id: (json['_id'] ?? json['id'] ?? '').toString(),

      // Ensure email is never null
      email: (json['email'] ?? '').toString(),

      // ✅ FIXED: Handle null name values properly
      name: (json['name'] ?? json['email']?.toString().split('@')[0] ?? 'User')
          .toString(),

      // Optional fields can be null
      avatar: json['avatar']?.toString(),
      bio: json['bio']?.toString(),

      // Provide fallback for timezone
      timezone: (json['timezone'] ?? 'UTC').toString(),

      // Handle teams array safely
      teams:
          (json['teams'] as List<dynamic>?)
              ?.map((teamId) => teamId.toString())
              .where((teamId) => teamId.isNotEmpty) // Filter out empty strings
              .toList() ??
          [],

      // Handle notification settings with fallback
      notificationSettings: json['notificationSettings'] != null
          ? UserNotificationSettings.fromJson(json['notificationSettings'])
          : UserNotificationSettings(), // Use default settings if null
      // Handle date parsing with fallback
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt']) ?? DateTime.now()
          : DateTime.now(),

      // Handle boolean with fallback
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
    if (name.isEmpty) return '?';
    final names = name.split(' ');
    if (names.length == 1) {
      return names[0].isNotEmpty ? names[0].substring(0, 1).toUpperCase() : '?';
    } else {
      final first = names[0].isNotEmpty ? names[0].substring(0, 1) : '';
      final last = names.last.isNotEmpty ? names.last.substring(0, 1) : '';
      return '${first}${last}'.toUpperCase();
    }
  }
}
