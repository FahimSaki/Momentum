import 'package:momentum/models/user.dart';

class CompletionRecord {
  final User user;
  final DateTime completedAt;

  CompletionRecord({required this.user, required this.completedAt});

  factory CompletionRecord.fromJson(Map<String, dynamic> json) {
    try {
      return CompletionRecord(
        // Handle both string user IDs and user objects
        user: json['user'] is String
            ? User.placeholder(id: json['user'])
            : User.fromJson(json['user']),
        completedAt: DateTime.parse(json['completedAt']),
      );
    } catch (e) {
      // Fallback for malformed data
      return CompletionRecord(
        user: User.placeholder(id: json['user']?.toString() ?? 'unknown'),
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
