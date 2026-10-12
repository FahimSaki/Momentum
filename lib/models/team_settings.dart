import 'package:momentum/models/notification_settings.dart';

class TeamSettings {
  final bool allowMemberInvite;
  final NotificationSettings notificationSettings;

  TeamSettings({
    this.allowMemberInvite = false,
    required this.notificationSettings,
  });

  factory TeamSettings.fromJson(Map<String, dynamic> json) {
    return TeamSettings(
      allowMemberInvite: json['allowMemberInvite'] ?? false,
      notificationSettings: NotificationSettings.fromJson(
        json['notificationSettings'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowMemberInvite': allowMemberInvite,
      'notificationSettings': notificationSettings.toJson(),
    };
  }
}
