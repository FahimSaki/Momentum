import 'package:momentum/models/profile_visibility.dart';
import 'package:momentum/models/user_notification_settings.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String? bio;
  final String timezone;
  final List teams;
  final UserNotificationSettings notificationSettings;
  final DateTime lastLoginAt;
  final bool isActive;
  final String inviteId;
  final bool isPublic;
  final ProfileVisibility profileVisibility;
  final bool isEmailVerified;
  final bool twoFactorEnabled;

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
    required this.inviteId,
    this.isPublic = true,
    required this.profileVisibility,
    this.isEmailVerified = true,
    this.twoFactorEnabled = false,
  });

  factory User.fromJson(Map json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? json['email']?.toString().split('@')[0] ?? 'User')
          .toString(),
      avatar: json['avatar']?.toString(),
      bio: json['bio']?.toString(),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      teams:
          (json['teams'] as List?)
              ?.map((t) => t.toString())
              .where((t) => t.isNotEmpty)
              .toList() ??
          [],
      notificationSettings: json['notificationSettings'] != null
          ? UserNotificationSettings.fromJson(json['notificationSettings'])
          : UserNotificationSettings(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt']) ?? DateTime.now()
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
      inviteId: json['inviteId'] ?? '',
      isPublic: json['isPublic'] ?? true,
      profileVisibility: json['profileVisibility'] != null
          ? ProfileVisibility.fromJson(json['profileVisibility'])
          : ProfileVisibility(),
      isEmailVerified: json['isEmailVerified'] ?? true,
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
    );
  }

  Map toJson() {
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
      'inviteId': inviteId,
      'isPublic': isPublic,
      'profileVisibility': profileVisibility.toJson(),
      'isEmailVerified': isEmailVerified,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }

  factory User.empty() {
    return User(
      id: '',
      email: '',
      name: '',
      notificationSettings: UserNotificationSettings(),
      lastLoginAt: DateTime.now(),
      inviteId: '',
      profileVisibility: ProfileVisibility(),
    );
  }

  String get initials {
    if (name.isEmpty) return '?';
    final names = name.split(' ');
    if (names.length == 1) {
      return names[0].isNotEmpty ? names[0].substring(0, 1).toUpperCase() : '?';
    }
    final first = names[0].isNotEmpty ? names[0].substring(0, 1) : '';
    final last = names.last.isNotEmpty ? names.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }
}
