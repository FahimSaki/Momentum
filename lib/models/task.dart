import 'package:momentum/models/user.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/completion_record.dart';

class Task {
  final String id;
  String name;
  String? description;
  List<User> assignedTo;
  User? assignedBy;
  Team? team;
  String priority;
  DateTime? dueDate;
  List<String> tags;
  List<DateTime> completedDays;
  List<CompletionRecord> completedBy;
  DateTime? lastCompletedDate;
  bool isArchived;
  DateTime? archivedAt;
  bool isTeamTask;
  String assignmentType;
  DateTime createdAt;
  DateTime updatedAt;

  Task({
    required this.id,
    required this.name,
    this.description,
    this.assignedTo = const [],
    this.assignedBy,
    this.team,
    this.priority = 'medium',
    this.dueDate,
    this.tags = const [],
    this.completedDays = const [],
    this.completedBy = const [],
    this.lastCompletedDate,
    this.isArchived = false,
    this.archivedAt,
    this.isTeamTask = false,
    this.assignmentType = 'individual',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      assignedTo:
          (json['assignedTo'] as List<dynamic>?)
              ?.map((user) => User.fromJson(user))
              .toList() ??
          [],
      assignedBy: json['assignedBy'] != null
          ? User.fromJson(json['assignedBy'])
          : null,
      // 🔧 FIX: Handle null team safely
      team: json['team'] != null && json['team'] is Map<String, dynamic>
          ? Team.fromJson(json['team'])
          : null,
      priority: json['priority'] ?? 'medium',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate']).toLocal()
          : null,
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map((tag) => tag.toString())
              .toList() ??
          [],
      completedDays:
          (json['completedDays'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e).toLocal())
              .toList() ??
          [],
      completedBy:
          (json['completedBy'] as List<dynamic>?)
              ?.map((completion) => CompletionRecord.fromJson(completion))
              .toList() ??
          [],
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.parse(json['lastCompletedDate']).toLocal()
          : null,
      isArchived: json['isArchived'] ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt']).toLocal()
          : null,
      isTeamTask: json['isTeamTask'] ?? false,
      assignmentType: json['assignmentType'] ?? 'individual',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'assignedTo': assignedTo.map((user) => user.toJson()).toList(),
      'assignedBy': assignedBy?.toJson(),
      'team': team?.toJson(),
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
      'completedDays': completedDays.map((e) => e.toIso8601String()).toList(),
      'completedBy': completedBy.map((c) => c.toJson()).toList(),
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'isTeamTask': isTeamTask,
      'assignmentType': assignmentType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool isAssignedTo(String userId) {
    return assignedTo.any((user) => user.id == userId);
  }

  bool isCompletedBy(String userId) {
    return completedBy.any((completion) => completion.user.id == userId);
  }

  // 🔧 ENHANCED: Better completion checking
  bool isCompletedToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if task is archived and has completion for today
    if (!isArchived) return false;

    return completedDays.any((completedDate) {
      final localDate = completedDate.toLocal();
      final completedDay = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );
      return completedDay.isAtSameMomentAs(today);
    });
  }

  // 🔧 NEW: Check if task is completed by specific user today
  bool isCompletedByUserToday(String userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return completedBy.any((completion) {
      if (completion.user.id != userId) return false;

      final completedDate = completion.completedAt.toLocal();
      final completedDay = DateTime(
        completedDate.year,
        completedDate.month,
        completedDate.day,
      );
      return completedDay.isAtSameMomentAs(today);
    });
  }

  // 🔧 ENHANCED: Better overdue logic
  bool get isOverdue {
    if (dueDate == null || isArchived) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);

    // Task is overdue if due date has passed and it's not completed today
    return dueDay.isBefore(today) && !isCompletedToday();
  }

  // 🔧 ENHANCED: Better due soon logic
  bool get isDueSoon {
    if (dueDate == null || isArchived) return false;

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final tomorrowDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    // Task is due soon if due tomorrow and not completed today
    return dueDay.isAtSameMomentAs(tomorrowDay) && !isCompletedToday();
  }

  String get priorityColor {
    switch (priority.toLowerCase()) {
      case 'low':
        return '#4CAF50'; // Green
      case 'medium':
        return '#FF9800'; // Orange
      case 'high':
        return '#FF5722'; // Red-Orange
      case 'urgent':
        return '#F44336'; // Red
      default:
        return '#FF9800'; // Default orange
    }
  }
}

// 🔧 ADD THIS EXTENSION AT THE END OF THE FILE
extension DateTimeComparison on DateTime {
  bool isAtSameMomentAs(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
