import 'package:flutter/material.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_invitation.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:momentum/services/team_service.dart';
import 'package:momentum/services/task_service.dart';
import 'package:momentum/services/notification_service.dart';
import 'package:momentum/database/widget_service.dart';
import 'package:momentum/database/timer_service.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TaskDatabase extends ChangeNotifier {
  final Logger logger = Logger();

  // Task management
  final List<Task> currentTasks = [];
  final List<Task> personalTasks = [];
  final List<Task> teamTasks = [];
  final List<DateTime> _historicalCompletions = [];

  // Team management
  final List<Team> userTeams = [];
  final List<TeamInvitation> pendingInvitations = [];

  // Notifications
  final List<AppNotification> notifications = [];
  int unreadNotificationCount = 0;

  // Current context
  Team? selectedTeam;
  String currentView = 'personal';

  // Services
  String? jwtToken;
  String? userId;
  TeamService? _teamService;
  TaskService? _taskService;
  NotificationService? _notificationService;
  final WidgetService _widgetService = WidgetService();
  TimerService? _timerService;

  bool _isInitialized = false;

  // Getters
  List<DateTime> get historicalCompletions =>
      List.unmodifiable(_historicalCompletions);
  bool get isInitialized => _isInitialized;

  List<Task> get activeTasks => currentTasks
      .where((task) => !task.isCompletedToday() && !task.isArchived)
      .toList();

  List<Task> get completedTasks =>
      currentTasks.where((task) => task.isCompletedToday()).toList();

  /// Returns the current user's role in [selectedTeam], or null if no team selected.
  String? get currentUserRoleInSelectedTeam {
    if (selectedTeam == null || userId == null) return null;
    final member = selectedTeam!.getMember(userId!);
    if (member != null) return member.role;
    if (selectedTeam!.isOwner(userId!)) return 'owner';
    return null;
  }

  /// Returns true if the current user can create tasks in the current context.
  bool get canCurrentUserCreateTasks {
    if (selectedTeam == null) return true; // personal workspace
    final role = currentUserRoleInSelectedTeam;
    return role == 'owner' || role == 'admin';
  }

  TaskDatabase() {
    if (!kIsWeb) {
      _initializeTimerService();
      _notificationService = NotificationService();
    }
  }

  void _initializeTimerService() {
    _timerService = TimerService(
      onPollingTick: () async => await _refreshData(),
      onMidnightCleanup: () async => await _handleMidnightCleanup(),
    );
  }

  Future<void> initialize({required String jwt, required String userId}) async {
    try {
      logger.i('Initializing TaskDatabase with userId: $userId');

      jwtToken = jwt;
      this.userId = userId;

      _teamService = TeamService(jwtToken: jwt);
      _taskService = TaskService(jwtToken: jwt);

      if (!kIsWeb) {
        await _notificationService?.init(jwtToken: jwt);
      }

      await Future.wait([
        _loadUserTeams(),
        _loadPendingInvitations(),
        _loadTasks(),
        _loadHistoricalCompletions(),
        _loadNotifications(),
      ]);

      if (!kIsWeb) {
        _startPolling();
        _scheduleMidnightCleanup();
      }

      await updateWidget();
      _isInitialized = true;
      logger.i('TaskDatabase initialization complete');
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'TaskDatabase initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
      _isInitialized = false;
      rethrow;
    }
  }

  void clearData() {
    logger.i('Clearing TaskDatabase data');
    currentTasks.clear();
    personalTasks.clear();
    teamTasks.clear();
    _historicalCompletions.clear();
    userTeams.clear();
    pendingInvitations.clear();
    notifications.clear();
    selectedTeam = null;
    currentView = 'personal';
    unreadNotificationCount = 0;
    jwtToken = null;
    userId = null;
    _teamService = null;
    _taskService = null;
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    try {
      if (_taskService == null) return;

      List<Task> tasks = [];
      if (selectedTeam != null) {
        tasks = await _taskService!.getTeamTasks(selectedTeam!.id);
      } else {
        tasks = await _taskService!.getUserTasks();
      }

      // ── FILTER: only keep tasks relevant to today ──────────────────────
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final filtered = tasks.where((task) {
        if (!task.isArchived) return true;
        if (task.archivedAt != null) {
          final archivedLocal = task.archivedAt!.toLocal();
          final archivedDay = DateTime(
            archivedLocal.year,
            archivedLocal.month,
            archivedLocal.day,
          );
          return archivedDay.isAtSameMomentAs(todayStart);
        }
        return task.isCompletedToday();
      }).toList();

      currentTasks.clear();
      currentTasks.addAll(filtered);
      _organizeTasksByType();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error loading tasks', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      if (_notificationService == null) return;
      final notifs = await _notificationService!.getNotifications();
      notifications.clear();
      notifications.addAll(notifs);
      unreadNotificationCount = notifs.where((n) => !n.isRead).length;
    } catch (e, stackTrace) {
      logger.w(
        'Error loading notifications (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
      unreadNotificationCount = notifications.where((n) => !n.isRead).length;
    }
  }

  Future<void> _loadUserTeams() async {
    try {
      final teams = await _teamService?.getUserTeams() ?? [];
      userTeams.clear();
      userTeams.addAll(teams);
    } catch (e, stackTrace) {
      logger.e('Error loading user teams', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final invitations = await _teamService?.getPendingInvitations() ?? [];
      pendingInvitations.clear();
      pendingInvitations.addAll(invitations);
    } catch (e, stackTrace) {
      logger.e(
        'Error loading pending invitations',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Team> createTeam(String name, {String? description}) async {
    try {
      final team = await _teamService!.createTeam(
        name,
        description: description,
      );
      userTeams.add(team);
      notifyListeners();
      return team;
    } catch (e, stackTrace) {
      logger.e('Error creating team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Team> getTeamDetails(String teamId) async {
    try {
      return await _teamService!.getTeamDetails(teamId);
    } catch (e, stackTrace) {
      logger.e('Error fetching team details', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateTeamSettings(
    String teamId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _teamService!.updateTeamSettings(teamId, settings);
      await _loadUserTeams();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'Error updating team settings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _teamService!.deleteTeam(teamId);
      userTeams.removeWhere((t) => t.id == teamId);
      if (selectedTeam?.id == teamId) {
        selectedTeam = null;
        currentView = 'personal';
        currentTasks.clear();
        personalTasks.clear();
        teamTasks.clear();
      }
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error deleting team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Leave a team (for non-owner members).
  Future<void> leaveTeam(String teamId) async {
    try {
      await _teamService!.leaveTeam(teamId);
      userTeams.removeWhere((t) => t.id == teamId);
      if (selectedTeam?.id == teamId) {
        selectedTeam = null;
        currentView = 'personal';
        currentTasks.clear();
        personalTasks.clear();
        teamTasks.clear();
      }
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error leaving team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Remove a member from a team (owner/admin only).
  Future<void> removeTeamMember(String teamId, String memberId) async {
    try {
      await _teamService!.removeTeamMember(teamId, memberId);
      await _loadUserTeams();
      // Keep selectedTeam reference fresh
      if (selectedTeam?.id == teamId) {
        final updated = userTeams.where((t) => t.id == teamId).firstOrNull;
        if (updated != null) selectedTeam = updated;
      }
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error removing team member', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> inviteToTeam({
    required String teamId,
    String? email,
    String? inviteId,
    String role = 'member',
    String? message,
  }) async {
    try {
      await _teamService!.inviteToTeam(
        teamId: teamId,
        email: email,
        inviteId: inviteId,
        role: role,
        message: message,
      );
    } catch (e, stackTrace) {
      logger.e('Error inviting to team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateTeamMemberRole(
    String teamId,
    String memberId,
    String role,
  ) async {
    try {
      await _teamService!.updateTeamMemberRole(teamId, memberId, role);
      await _loadUserTeams();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'Error updating team member role',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> respondToInvitation(String invitationId, bool accept) async {
    try {
      final response = accept ? 'accepted' : 'declined';
      await _teamService!.respondToInvitation(invitationId, response);
      pendingInvitations.removeWhere((inv) => inv.id == invitationId);
      if (accept) await _loadUserTeams();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'Error responding to invitation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void selectTeam(Team? team) {
    selectedTeam = team;
    currentView = team != null ? 'team' : 'personal';
    currentTasks.clear();
    personalTasks.clear();
    teamTasks.clear();
    notifyListeners();
    _loadTasks();
  }

  void _organizeTasksByType() {
    personalTasks.clear();
    teamTasks.clear();

    for (final task in currentTasks) {
      if (task.isTeamTask) {
        teamTasks.add(task);
      } else {
        personalTasks.add(task);
      }
    }
  }

  Future<void> _loadHistoricalCompletions() async {
    try {
      final historicalData =
          await _taskService?.getTaskHistory(teamId: selectedTeam?.id) ?? [];
      _historicalCompletions.clear();
      _historicalCompletions.addAll(historicalData);
    } catch (e, stackTrace) {
      logger.w(
        'Could not load historical completions (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Task> createTask({
    required String name,
    String? description,
    List<String>? assignedTo,
    String? teamId,
    String priority = 'medium',
    DateTime? dueDate,
    List<String>? tags,
    String assignmentType = 'individual',
  }) async {
    try {
      if (_taskService == null) throw Exception('Task service not initialized');

      String? validTeamId;
      if (teamId != null && teamId.isNotEmpty) {
        final team = userTeams.firstWhere(
          (t) => t.id == teamId,
          orElse: () => throw Exception('Selected team not found'),
        );
        validTeamId = team.id;
      }

      final task = await _taskService!.createTask(
        name: name.trim(),
        description: description?.trim(),
        assignedTo: assignedTo,
        teamId: validTeamId,
        priority: priority,
        dueDate: dueDate,
        tags: tags ?? [],
        assignmentType: assignmentType,
      );

      if (task.isTeamTask && validTeamId != null) {
        teamTasks.add(task);
      } else {
        personalTasks.add(task);
      }
      currentTasks.add(task);
      _organizeTasksByType();

      await updateWidget();
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 500), () {
        _loadTasks().catchError(
          (e) => logger.w('Background task refresh failed: $e'),
        );
      });

      return task;
    } catch (e, stackTrace) {
      logger.e(
        'Error in TaskDatabase.createTask',
        error: e,
        stackTrace: stackTrace,
      );
      String userMessage;
      final msg = e.toString();
      if (msg.contains('Task service not initialized')) {
        userMessage = 'App not ready - please restart and try again';
      } else if (msg.contains('Selected team not found')) {
        userMessage = 'Selected team is no longer available';
      } else if (msg.contains('Network error')) {
        userMessage = 'Network error - check your connection';
      } else if (msg.contains('timeout')) {
        userMessage = 'Request timeout - please try again';
      } else if (msg.contains('401') || msg.contains('unauthorized')) {
        userMessage = 'Session expired - please login again';
      } else if (msg.contains('403') || msg.contains('permission')) {
        userMessage = 'Permission denied';
      } else {
        userMessage =
            'Failed to create task: ${msg.replaceFirst('Exception: ', '')}';
      }
      throw Exception(userMessage);
    }
  }

  Future<void> completeTask(String taskId, bool isCompleted) async {
    try {
      if (_taskService == null) throw Exception('Task service not initialized');

      final updatedTask = await _taskService!.completeTask(taskId, isCompleted);

      bool taskFound = false;
      for (int i = 0; i < currentTasks.length; i++) {
        if (currentTasks[i].id == taskId) {
          currentTasks[i] = updatedTask;
          taskFound = true;
          break;
        }
      }
      for (int i = 0; i < personalTasks.length; i++) {
        if (personalTasks[i].id == taskId) {
          personalTasks[i] = updatedTask;
          break;
        }
      }
      for (int i = 0; i < teamTasks.length; i++) {
        if (teamTasks[i].id == taskId) {
          teamTasks[i] = updatedTask;
          break;
        }
      }

      if (!taskFound) {
        await _loadTasks();
      } else {
        _organizeTasksByType();
      }

      await updateWidget();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'Error in TaskDatabase.completeTask',
        error: e,
        stackTrace: stackTrace,
      );
      String userMessage =
          'Failed to ${isCompleted ? 'complete' : 'uncomplete'} task';
      final msg = e.toString();
      if (msg.contains('Network error')) {
        userMessage = 'Network error - check your connection';
      } else if (msg.contains('timeout')) {
        userMessage = 'Request timeout - please try again';
      } else if (msg.contains('401') || msg.contains('unauthorized')) {
        userMessage = 'Session expired - please login again';
      }
      throw Exception(userMessage);
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final updatedTask = await _taskService!.updateTask(taskId, updates);
      final index = currentTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        currentTasks[index] = updatedTask;
        _organizeTasksByType();
        await updateWidget();
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _taskService!.deleteTask(taskId);
      currentTasks.removeWhere((t) => t.id == taskId);
      _organizeTasksByType();
      await _loadHistoricalCompletions();
      await updateWidget();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationService?.markAsRead(notificationId);
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index] = AppNotification(
          id: notifications[index].id,
          recipient: notifications[index].recipient,
          sender: notifications[index].sender,
          team: notifications[index].team,
          task: notifications[index].task,
          type: notifications[index].type,
          title: notifications[index].title,
          message: notifications[index].message,
          data: notifications[index].data,
          isRead: true,
          readAt: DateTime.now(),
          createdAt: notifications[index].createdAt,
        );
        unreadNotificationCount = notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e(
        'Error marking notification as read',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _notificationService?.markAllAsRead();
      for (int i = 0; i < notifications.length; i++) {
        if (!notifications[i].isRead) {
          notifications[i] = AppNotification(
            id: notifications[i].id,
            recipient: notifications[i].recipient,
            sender: notifications[i].sender,
            team: notifications[i].team,
            task: notifications[i].task,
            type: notifications[i].type,
            title: notifications[i].title,
            message: notifications[i].message,
            data: notifications[i].data,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: notifications[i].createdAt,
          );
        }
      }
      unreadNotificationCount = 0;
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e(
        'Error marking all notifications as read',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _startPolling() {
    if (kIsWeb) return;
    _timerService?.startPolling();
  }

  void _scheduleMidnightCleanup() {
    if (kIsWeb) return;
    _timerService?.scheduleMidnightCleanup();
  }

  Future<void> _refreshData() async {
    try {
      if (!_isInitialized) return;
      await Future.wait([
        _loadTasks(),
        _loadNotifications(),
        _loadPendingInvitations(),
      ]);
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e('Error refreshing data', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _handleMidnightCleanup() async {
    try {
      if (!_isInitialized) return;
      await _loadHistoricalCompletions();
      await _loadTasks();
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e(
        'Error handling midnight cleanup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> refreshData() async => await _refreshData();

  Future<void> updateWidget() async {
    if (kIsWeb) return;
    try {
      await _widgetService.updateWidgetWithHistoricalData(
        _historicalCompletions,
        currentTasks,
        selectedTeam: selectedTeam,
      );
    } catch (e, stackTrace) {
      logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }

  Future<Map<String, int>> getDashboardStats() async {
    try {
      return await _taskService?.getDashboardStats(teamId: selectedTeam?.id) ??
          {
            'totalTasks': 0,
            'completedToday': 0,
            'overdueTasks': 0,
            'upcomingTasks': 0,
          };
    } catch (e, stackTrace) {
      logger.e(
        'Error getting dashboard stats',
        error: e,
        stackTrace: stackTrace,
      );
      return {
        'totalTasks': 0,
        'completedToday': 0,
        'overdueTasks': 0,
        'upcomingTasks': 0,
      };
    }
  }

  Map<String, int> calculateDashboardStats() {
    final now = DateTime.now();
    final completedToday = currentTasks
        .where((task) => task.isCompletedToday())
        .length;
    final overdueTasks = currentTasks
        .where(
          (task) =>
              task.dueDate != null &&
              task.dueDate!.isBefore(now) &&
              !task.isCompletedToday(),
        )
        .length;
    final upcomingTasks = currentTasks
        .where(
          (task) =>
              task.dueDate != null &&
              task.dueDate!.isAfter(now) &&
              !task.isCompletedToday(),
        )
        .length;

    return {
      'totalTasks': currentTasks.length,
      'completedToday': completedToday,
      'overdueTasks': overdueTasks,
      'upcomingTasks': upcomingTasks,
    };
  }

  @override
  void dispose() {
    logger.i('Disposing TaskDatabase');
    _timerService?.dispose();
    super.dispose();
  }
}
