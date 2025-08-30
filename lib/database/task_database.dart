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
  String currentView = 'personal'; // 'personal', 'team', 'all'

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
  List<Task> get activeTasks =>
      currentTasks.where((task) => !task.isArchived).toList();
  List<Task> get completedTasks => currentTasks
      .where((task) => task.isArchived && task.isCompletedToday())
      .toList();

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

  // Initialize the database with authentication
  Future<void> initialize({required String jwt, required String userId}) async {
    try {
      logger.i('Initializing TaskDatabase with userId: $userId');

      this.jwtToken = jwt;
      this.userId = userId;

      // Initialize services
      _teamService = TeamService(jwtToken: jwt);
      _taskService = TaskService(jwtToken: jwt, userId: userId);

      if (!kIsWeb) {
        await _notificationService?.init(jwtToken: jwt);
      }

      // Load initial data
      await Future.wait([
        _loadUserTeams(),
        _loadPendingInvitations(),
        _loadTasks(),
        _loadHistoricalCompletions(),
        _loadNotifications(),
      ]);

      // Start background services (mobile only)
      if (!kIsWeb) {
        _startPolling();
        _scheduleMidnightCleanup();
      }

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

  // Clear all data (for logout)
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

  // Team Management Methods
  Future<void> _loadUserTeams() async {
    try {
      final teams = await _teamService?.getUserTeams() ?? [];
      userTeams.clear();
      userTeams.addAll(teams);
      logger.i('Loaded ${teams.length} user teams');
    } catch (e, stackTrace) {
      logger.e('Error loading user teams', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final invitations = await _teamService?.getPendingInvitations() ?? [];
      pendingInvitations.clear();
      pendingInvitations.addAll(invitations);
      logger.i('Loaded ${invitations.length} pending invitations');
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

  Future<void> inviteToTeam({
    required String teamId,
    required String email,
    String role = 'member',
    String? message,
  }) async {
    try {
      await _teamService!.inviteToTeam(
        teamId: teamId,
        email: email,
        role: role,
        message: message,
      );
    } catch (e, stackTrace) {
      logger.e('Error inviting to team', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> respondToInvitation(String invitationId, bool accept) async {
    try {
      final response = accept ? 'accepted' : 'declined';
      await _teamService!.respondToInvitation(invitationId, response);

      // Remove invitation from local list
      pendingInvitations.removeWhere((inv) => inv.id == invitationId);

      // Refresh teams if accepted
      if (accept) {
        await _loadUserTeams();
      }

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
    _filterCurrentTasks();
    notifyListeners();
  }

  // Task Management Methods
  Future<void> _loadTasks() async {
    try {
      List<Task> tasks = [];

      if (selectedTeam != null) {
        // Load team tasks
        tasks = await _taskService!.getTeamTasks(selectedTeam!.id);
      } else {
        // Load all user tasks (personal + team)
        tasks = await _taskService!.getUserTasks();
      }

      currentTasks.clear();
      currentTasks.addAll(tasks);

      _organizeTasksByType();
      logger.d('Loaded ${tasks.length} tasks');
    } catch (e, stackTrace) {
      logger.e('Error loading tasks', error: e, stackTrace: stackTrace);
    }
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

  void _filterCurrentTasks() {
    // This method can be used to filter tasks based on current view/team
    // Implementation depends on your specific filtering needs
    notifyListeners();
  }

  Future<void> _loadHistoricalCompletions() async {
    try {
      final historicalData =
          await _taskService?.getTaskHistory(teamId: selectedTeam?.id) ?? [];
      _historicalCompletions.clear();
      _historicalCompletions.addAll(historicalData);
      logger.i(
        'Loaded ${_historicalCompletions.length} historical completions',
      );
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
      final task = await _taskService!.createTask(
        name: name,
        description: description,
        assignedTo: assignedTo,
        teamId: teamId ?? selectedTeam?.id,
        priority: priority,
        dueDate: dueDate,
        tags: tags,
        assignmentType: assignmentType,
      );

      currentTasks.add(task);
      _organizeTasksByType();
      notifyListeners();

      return task;
    } catch (e, stackTrace) {
      logger.e('Error creating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> completeTask(String taskId, bool isCompleted) async {
    try {
      final updatedTask = await _taskService!.completeTask(taskId, isCompleted);

      // Update local task
      final index = currentTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        currentTasks[index] = updatedTask;
        _organizeTasksByType();
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e('Error completing task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final updatedTask = await _taskService!.updateTask(taskId, updates);

      // Update local task
      final index = currentTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        currentTasks[index] = updatedTask;
        _organizeTasksByType();
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

      // Remove from local list
      currentTasks.removeWhere((t) => t.id == taskId);
      _organizeTasksByType();

      // Reload historical data
      await _loadHistoricalCompletions();
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Notification Management
  Future<void> _loadNotifications() async {
    try {
      final notifs = await _notificationService?.getNotifications() ?? [];
      notifications.clear();
      notifications.addAll(notifs);

      unreadNotificationCount = notifs.where((n) => !n.isRead).length;
      logger.i(
        'Loaded ${notifs.length} notifications (${unreadNotificationCount} unread)',
      );
    } catch (e, stackTrace) {
      logger.w(
        'Error loading notifications (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationService?.markAsRead(notificationId);

      // Update local notification
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        // Create updated notification (since AppNotification is immutable)
        final updatedNotification = AppNotification(
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

        notifications[index] = updatedNotification;
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

      // Update all local notifications
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

  // Background services
  void _startPolling() {
    if (kIsWeb) {
      logger.w('Polling disabled on web to reduce CPU load');
      return;
    }
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

      // Reload historical data after cleanup
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

  Future<void> refreshData() async {
    await _refreshData();
  }

  Future<void> updateWidget() async {
    if (kIsWeb) return;

    try {
      // Combine personal and team tasks for widget
      await _widgetService.updateWidgetWithHistoricalData(
        _historicalCompletions,
        currentTasks,
      );
    } catch (e, stackTrace) {
      logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }

  // Utility methods for dashboard stats
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

  @override
  void dispose() {
    logger.i('Disposing TaskDatabase');
    _timerService?.dispose();
    super.dispose();
  }
}
