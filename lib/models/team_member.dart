import 'package:momentum/models/user.dart';

class TeamMember {
  final User user;
  final String role; // 'owner', 'admin', 'member'
  final DateTime joinedAt;
  final User? invitedBy;

  TeamMember({
    required this.user,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      user: User.fromJson(json['user']),
      role: json['role'] ?? 'member',
      joinedAt: DateTime.parse(json['joinedAt']),
      invitedBy: json['invitedBy'] != null
          ? User.fromJson(json['invitedBy'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy?.toJson(),
    };
  }

  factory TeamMember.empty() {
    return TeamMember(user: User.empty(), role: '', joinedAt: DateTime.now());
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';
  bool get canInvite => role == 'owner' || role == 'admin';
  bool get canDeleteTasks => role == 'owner' || role == 'admin';
}
