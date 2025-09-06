import 'package:momentum/models/user.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/models/team_settings.dart';
import 'package:momentum/models/notification_settings.dart';

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
    // 🔧 FIX: Add comprehensive null checking
    if (json.isEmpty) {
      throw ArgumentError('Cannot create Team from empty JSON');
    }

    try {
      return Team(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? 'Unknown Team',
        description: json['description'],
        // 🔧 FIX: Handle owner field properly
        owner: json['owner'] != null && json['owner'] is Map<String, dynamic>
            ? User.fromJson(json['owner'])
            : User.empty(), // Fallback to empty user
        // 🔧 FIX: Handle members array safely
        members: json['members'] != null && json['members'] is List
            ? (json['members'] as List<dynamic>)
                  .where((memberJson) => memberJson != null)
                  .map((memberJson) {
                    try {
                      return TeamMember.fromJson(memberJson);
                    } catch (e) {
                      print('Error parsing team member: $e');
                      return null;
                    }
                  })
                  .where((member) => member != null)
                  .cast<TeamMember>()
                  .toList()
            : [],
        // 🔧 FIX: Handle settings with default fallback
        settings:
            json['settings'] != null && json['settings'] is Map<String, dynamic>
            ? TeamSettings.fromJson(json['settings'])
            : TeamSettings(notificationSettings: NotificationSettings()),
        // 🔧 FIX: Handle date parsing with fallbacks
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
            : DateTime.now(),
        isActive: json['isActive'] ?? true,
      );
    } catch (e, stackTrace) {
      print('Error creating Team from JSON: $e');
      print('JSON data: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
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
    try {
      final member = members.firstWhere(
        (m) => m.user.id == userId,
        orElse: () => TeamMember.empty(),
      );
      return member.role == 'admin' || member.role == 'owner';
    } catch (e) {
      return false;
    }
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
