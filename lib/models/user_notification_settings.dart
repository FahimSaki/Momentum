class UserNotificationSettings {
  final bool email;
  final bool push;
  final bool inApp;
  final bool taskAssigned;
  final bool taskCompleted;
  final bool teamInvitations;
  final bool dailyReminder;

  UserNotificationSettings({
    this.email = true,
    this.push = true,
    this.inApp = true,
    this.taskAssigned = true,
    this.taskCompleted = true,
    this.teamInvitations = true,
    this.dailyReminder = false,
  });

  factory UserNotificationSettings.fromJson(Map<String, dynamic> json) {
    return UserNotificationSettings(
      email: json['email'] ?? true,
      push: json['push'] ?? true,
      inApp: json['inApp'] ?? true,
      taskAssigned: json['taskAssigned'] ?? true,
      taskCompleted: json['taskCompleted'] ?? true,
      teamInvitations: json['teamInvitations'] ?? true,
      dailyReminder: json['dailyReminder'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'push': push,
      'inApp': inApp,
      'taskAssigned': taskAssigned,
      'taskCompleted': taskCompleted,
      'teamInvitations': teamInvitations,
      'dailyReminder': dailyReminder,
    };
  }
}
