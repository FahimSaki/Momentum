import 'package:momentum/models/user.dart';

class CompletionRecord {
  final User user;
  final DateTime completedAt;

  CompletionRecord({required this.user, required this.completedAt});

  factory CompletionRecord.fromJson(Map<String, dynamic> json) {
    return CompletionRecord(
      user: User.fromJson(json['user']),
      completedAt: DateTime.parse(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
