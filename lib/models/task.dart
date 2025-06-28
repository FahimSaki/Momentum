// This file was renamed from habit.dart to task.dart
// ...existing Task class code from habit.dart...

class Task {
  final String id;
  String title;
  String? description;
  String status;
  String assignedTo;
  String createdBy;
  DateTime createdAt;
  DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.status = 'pending',
    required this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'] ?? 'pending',
      assignedTo: json['assignedTo'] is Map
          ? json['assignedTo']['_id'] ?? ''
          : json['assignedTo'] ?? '',
      createdBy: json['createdBy'] is Map
          ? json['createdBy']['_id'] ?? ''
          : json['createdBy'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
