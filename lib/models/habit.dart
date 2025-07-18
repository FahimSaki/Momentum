class Habit {
  final String id;
  String name;
  List<DateTime> completedDays;
  DateTime? lastCompletedDate;
  bool isArchived;
  DateTime? archivedAt;

  Habit({
    required this.id,
    required this.name,
    this.completedDays = const [],
    this.lastCompletedDate,
    this.isArchived = false,
    this.archivedAt,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      completedDays: (json['completedDays'] ?? json['completed_days'] ?? [])
          .map<DateTime>((e) => DateTime.parse(e))
          .toList(),
      lastCompletedDate:
          (json['lastCompletedDate'] ?? json['last_completed_date']) != null
              ? DateTime.parse(
                  json['lastCompletedDate'] ?? json['last_completed_date'])
              : null,
      isArchived: json['isArchived'] ?? json['is_archived'] ?? false,
      archivedAt: (json['archivedAt'] ?? json['archived_at']) != null
          ? DateTime.parse(json['archivedAt'] ?? json['archived_at'])
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
