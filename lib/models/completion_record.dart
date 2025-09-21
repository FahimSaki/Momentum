import 'package:momentum/models/profile_visibility.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/models/user_notification_settings.dart';

class CompletionRecord {
  final User user;
  final DateTime completedAt;

  CompletionRecord({required this.user, required this.completedAt});

  factory CompletionRecord.fromJson(Map<String, dynamic> json) {
    try {
      return CompletionRecord(
        // Handle both string user IDs and user objects
        user: json['user'] is String
            ? User(
                id: json['user'],
                email: '', // Placeholder values when only ID is provided
                name: 'Unknown User',
                notificationSettings: UserNotificationSettings(),
                lastLoginAt: DateTime.now(),
                inviteId: '',
                profileVisibility: ProfileVisibility(),
              )
            : User.fromJson(json['user']),
        completedAt: DateTime.parse(json['completedAt']),
      );
    } catch (e) {
      // Fallback for malformed data
      return CompletionRecord(
        user: User(
          id: json['user']?.toString() ?? 'unknown',
          email: '',
          name: 'Unknown User',
          notificationSettings: UserNotificationSettings(),
          lastLoginAt: DateTime.now(),
          inviteId: '',
          profileVisibility: ProfileVisibility(),
        ),
        completedAt:
            DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
