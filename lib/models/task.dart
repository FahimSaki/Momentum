class Task {
  final String id;
  String name;
  List<DateTime> completedDays;
  DateTime? lastCompletedDate;
  bool isArchived;
  DateTime? archivedAt;

  Task({
    required this.id,
    required this.name,
    this.completedDays = const [],
    this.lastCompletedDate,
    this.isArchived = false,
    this.archivedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      completedDays: (json['completedDays'] ?? json['completed_days'] ?? [])
          .map<DateTime>(
            (e) => DateTime.parse(e).toLocal(),
          ) // <- Convert to local
          .toList(),
      lastCompletedDate:
          (json['lastCompletedDate'] ?? json['last_completed_date']) != null
          ? DateTime.parse(
                  json['lastCompletedDate'] ?? json['last_completed_date'],
                )
                .toLocal() // <- Convert to local
          : null,
      isArchived: json['isArchived'] ?? json['is_archived'] ?? false,
      archivedAt: (json['archivedAt'] ?? json['archived_at']) != null
          ? DateTime.parse(json['archivedAt'] ?? json['archived_at'])
                .toLocal() // <- Convert to local
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'completed_days': completedDays.map((e) => e.toIso8601String()).toList(),
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
    };
  }
}
