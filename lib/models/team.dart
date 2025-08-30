import 'package:momentum/models/user.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/models/team_settings.dart';

class Team {
  final String id;
  final String name;
  final String? description;
  final User owner;
  final List<TeamMember> members;
  final TeamSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Team({
    required this.id,
    required this.name,
    this.description,
    required this.owner,
    required this.members,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      owner: User.fromJson(json['owner']),
      members:
          (json['members'] as List<dynamic>?)
              ?.map((memberJson) => TeamMember.fromJson(memberJson))
              .toList() ??
          [],
      settings: TeamSettings.fromJson(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'owner': owner.toJson(),
      'members': members.map((m) => m.toJson()).toList(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Helper methods
  bool isOwner(String userId) => owner.id == userId;

  bool isAdmin(String userId) {
    final member = members.firstWhere(
      (m) => m.user.id == userId,
      orElse: () => TeamMember.empty(),
    );
    return member.role == 'admin' || member.role == 'owner';
  }

  bool isMember(String userId) {
    return members.any((m) => m.user.id == userId);
  }

  TeamMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.user.id == userId);
    } catch (e) {
      return null;
    }
  }
}
