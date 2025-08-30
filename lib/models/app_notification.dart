import 'package:momentum/models/user.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/task.dart';

class AppNotification {
  final String id;
  final User recipient;
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
    required this.recipient,
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
      id: json['_id'] ?? json['id'],
      recipient: User.fromJson(json['recipient']),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      team: json['team'] != null ? Team.fromJson(json['team']) : null,
      task: json['task'] != null ? Task.fromJson(json['task']) : null,
      type: json['type'],
      title: json['title'],
      message: json['message'],
      data: json['data'],
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
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
