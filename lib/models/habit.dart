class Habit {
  final int id;
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
      id: json['id'],
      name: json['name'],
      completedDays: (json['completed_days'] as List)
          .map((e) => DateTime.parse(e))
          .toList(),
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'])
          : null,
      isArchived: json['is_archived'] ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completed_days': completedDays.map((e) => e.toIso8601String()).toList(),
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
    };
  }
}
