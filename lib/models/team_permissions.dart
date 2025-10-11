class TeamPermissions {
  final bool canCreateTasks;
  final bool canEditOwnTasks;
  final bool canEditAllTasks;
  final bool canDeleteOwnTasks;
  final bool canDeleteAllTasks;
  final bool canCompleteTasks;
  final bool canInviteMembers;
  final bool canRemoveMembers;
  final bool canEditSettings;
  final bool canDeleteTeam;
  final bool canViewTasks;
  final bool canAssignTasks;

  const TeamPermissions({
    required this.canCreateTasks,
    required this.canEditOwnTasks,
    required this.canEditAllTasks,
    required this.canDeleteOwnTasks,
    required this.canDeleteAllTasks,
    required this.canCompleteTasks,
    required this.canInviteMembers,
    required this.canRemoveMembers,
    required this.canEditSettings,
    required this.canDeleteTeam,
    required this.canViewTasks,
    required this.canAssignTasks,
  });

  // Owner permissions - full access
  static const owner = TeamPermissions(
    canCreateTasks: true,
    canEditOwnTasks: true,
    canEditAllTasks: true,
    canDeleteOwnTasks: true,
    canDeleteAllTasks: true,
    canCompleteTasks: true,
    canInviteMembers: true,
    canRemoveMembers: true,
    canEditSettings: true,
    canDeleteTeam: true,
    canViewTasks: true,
    canAssignTasks: true,
  );

  // Admin permissions - almost full access
  static const admin = TeamPermissions(
    canCreateTasks: true,
    canEditOwnTasks: true,
    canEditAllTasks: true,
    canDeleteOwnTasks: true,
    canDeleteAllTasks: true,
    canCompleteTasks: true,
    canInviteMembers: true,
    canRemoveMembers: true,
    canEditSettings: true,
    canDeleteTeam: false, // Only owner can delete team
    canViewTasks: true,
    canAssignTasks: true,
  );

  // Member permissions - limited access
  static const member = TeamPermissions(
    canCreateTasks: false, // Members can't create tasks
    canEditOwnTasks: false, // Members can't edit tasks
    canEditAllTasks: false,
    canDeleteOwnTasks: false, // Members can't delete tasks
    canDeleteAllTasks: false,
    canCompleteTasks: true, // Members CAN complete tasks assigned to them
    canInviteMembers: false,
    canRemoveMembers: false,
    canEditSettings: false,
    canDeleteTeam: false,
    canViewTasks: true, // Members CAN view tasks
    canAssignTasks: false,
  );

  // Get permissions based on role
  static TeamPermissions forRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return owner;
      case 'admin':
        return admin;
      case 'member':
      default:
        return member;
    }
  }

  // Check if user can edit a specific task
  bool canEditTask(String taskCreatorId, String currentUserId) {
    if (canEditAllTasks) return true;
    if (canEditOwnTasks && taskCreatorId == currentUserId) return true;
    return false;
  }

  // Check if user can delete a specific task
  bool canDeleteTask(String taskCreatorId, String currentUserId) {
    if (canDeleteAllTasks) return true;
    if (canDeleteOwnTasks && taskCreatorId == currentUserId) return true;
    return false;
  }
}
