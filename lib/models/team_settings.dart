import 'package:momentum/models/notification_settings.dart';

class TeamSettings {
  final bool allowMemberInvite;
  final bool taskAutoDelete;
  final NotificationSettings notificationSettings;

  TeamSettings({
    this.allowMemberInvite = false,
    this.taskAutoDelete = true,
    required this.notificationSettings,
  });

  factory TeamSettings.fromJson(Map<String, dynamic> json) {
    return TeamSettings(
      allowMemberInvite: json['allowMemberInvite'] ?? false,
      taskAutoDelete: json['taskAutoDelete'] ?? true,
      notificationSettings: NotificationSettings.fromJson(
        json['notificationSettings'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowMemberInvite': allowMemberInvite,
      'taskAutoDelete': taskAutoDelete,
      'notificationSettings': notificationSettings.toJson(),
    };
  }
}
