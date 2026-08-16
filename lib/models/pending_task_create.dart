/// A personal-task creation request that couldn't reach the backend, kept
/// around so [SyncQueueService] can replay it once connectivity returns.
class PendingTaskCreate {
  final String localId;
  final String name;
  final String? description;
  final List<String>? assignedTo;
  final String? teamId;
  final String priority;
  final DateTime? dueDate;
  final List<String>? tags;
  final String assignmentType;
  final DateTime queuedAt;

  PendingTaskCreate({
    required this.localId,
    required this.name,
    this.description,
    this.assignedTo,
    this.teamId,
    required this.priority,
    this.dueDate,
    this.tags,
    required this.assignmentType,
    required this.queuedAt,
  });

  factory PendingTaskCreate.fromJson(Map<String, dynamic> json) {
    return PendingTaskCreate(
      localId: json['localId'],
      name: json['name'],
      description: json['description'],
      assignedTo: (json['assignedTo'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      teamId: json['teamId'],
      priority: json['priority'] ?? 'medium',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'])?.toLocal()
          : null,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
      assignmentType: json['assignmentType'] ?? 'individual',
      queuedAt: DateTime.tryParse(json['queuedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'name': name,
      'description': description,
      'assignedTo': assignedTo,
      'teamId': teamId,
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
      'assignmentType': assignmentType,
      'queuedAt': queuedAt.toIso8601String(),
    };
  }
}
