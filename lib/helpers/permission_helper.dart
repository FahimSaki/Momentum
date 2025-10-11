import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_permissions.dart';
import 'package:momentum/models/task.dart';

class PermissionHelper {
  // Get user's permissions for a team
  static TeamPermissions getUserPermissions(Team team, String userId) {
    final member = team.getMember(userId);
    if (member == null) {
      return TeamPermissions.member; // Default to member if not found
    }
    return TeamPermissions.forRole(member.role);
  }

  // Check if user can perform action on task
  static bool canUserEditTask(Team team, Task task, String userId) {
    final permissions = getUserPermissions(team, userId);
    final taskCreatorId = task.assignedBy?.id ?? '';
    return permissions.canEditTask(taskCreatorId, userId);
  }

  static bool canUserDeleteTask(Team team, Task task, String userId) {
    final permissions = getUserPermissions(team, userId);
    final taskCreatorId = task.assignedBy?.id ?? '';
    return permissions.canDeleteTask(taskCreatorId, userId);
  }

  static bool canUserCompleteTask(Task task, String userId) {
    // Users can complete tasks assigned to them
    return task.isAssignedTo(userId);
  }

  // Get user's role in team
  static String getUserRole(Team team, String userId) {
    final member = team.getMember(userId);
    return member?.role ?? 'member';
  }

  // Get user's role display name
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'member':
      default:
        return 'Member';
    }
  }

  // Get role badge color
  static String getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return '#FFD700'; // Gold
      case 'admin':
        return '#FF6B6B'; // Red
      case 'member':
      default:
        return '#4ECDC4'; // Teal
    }
  }
}
