import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_permissions.dart';
import 'package:momentum/models/task.dart';

class PermissionHelper {
  static TeamPermissions getUserPermissions(Team team, String userId) {
    final member = team.getMember(userId);
    if (member == null) return TeamPermissions.member;
    return TeamPermissions.forRole(member.role);
  }

  static bool canUserEditTask(Team team, Task task, String userId) {
    final permissions = getUserPermissions(team, userId);
    return permissions.canEditTask(task.assignedBy?.id ?? '', userId);
  }

  static bool canUserDeleteTask(Team team, Task task, String userId) {
    final permissions = getUserPermissions(team, userId);
    return permissions.canDeleteTask(task.assignedBy?.id ?? '', userId);
  }

  static bool canUserCompleteTask(Task task, String userId) {
    return task.isAssignedTo(userId);
  }

  static String getUserRole(Team team, String userId) {
    if (team.owner.id == userId) return 'owner';
    final member = team.getMember(userId);
    return member?.role ?? 'member';
  }
}
