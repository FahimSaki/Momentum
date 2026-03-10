class NotificationSettings {
  final bool taskAssigned;
  final bool taskCompleted;
  final bool memberJoined;

  NotificationSettings({
    this.taskAssigned = true,
    this.taskCompleted = true,
    this.memberJoined = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      taskAssigned: json['taskAssigned'] ?? true,
      taskCompleted: json['taskCompleted'] ?? true,
      memberJoined: json['memberJoined'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskAssigned': taskAssigned,
      'taskCompleted': taskCompleted,
      'memberJoined': memberJoined,
    };
  }
}
