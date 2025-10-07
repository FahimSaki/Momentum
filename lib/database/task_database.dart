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

  // Better getters for task states
  List<Task> get activeTasks {
    return currentTasks.where((task) {
      // A task is active if it's not archived OR not completed today
      return !task.isArchived || !task.isCompletedToday();
    }).toList();
  }

  List<Task> get completedTasks {
    return currentTasks.where((task) {
      // A task is in completed list if it's archived AND completed today
      return task.isArchived && task.isCompletedToday();
    }).toList();
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

  // Initialize the database with authentication
  Future<void> initialize({required String jwt, required String userId}) async {
    try {
      logger.i('Initializing TaskDatabase with userId: $userId');

      jwtToken = jwt;
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

  // Better task loading with error handling
  Future<void> _loadTasks() async {
    try {
      logger.i('Loading tasks...');

      if (_taskService == null) {
        logger.w('TaskService not initialized, skipping task loading');
        return;
      }

      List<Task> tasks = [];

      if (selectedTeam != null) {
        // Load team tasks
        tasks = await _taskService!.getTeamTasks(selectedTeam!.id);
        logger.d('Loaded ${tasks.length} team tasks');
      } else {
        // Load all user tasks (personal + team)
        tasks = await _taskService!.getUserTasks();
        logger.d('Loaded ${tasks.length} user tasks');
      }

      // Update local state
      currentTasks.clear();
      currentTasks.addAll(tasks);

      _organizeTasksByType();
      logger.i('Tasks loaded and organized successfully');
    } catch (e, stackTrace) {
      logger.e('Error loading tasks', error: e, stackTrace: stackTrace);

      // Don't clear existing tasks on error - keep what we have
      logger.w(
        'Keeping existing ${currentTasks.length} tasks due to load error',
      );
    }
  }

  // notification loading
  Future<void> _loadNotifications() async {
    try {
      if (_notificationService == null) {
        logger.w('NotificationService not available');
        return;
      }

      final notifs = await _notificationService!.getNotifications();
      notifications.clear();
      notifications.addAll(notifs);

      unreadNotificationCount = notifs.where((n) => !n.isRead).length;
      logger.i(
        'Loaded ${notifs.length} notifications ($unreadNotificationCount unread)',
      );
    } catch (e, stackTrace) {
      logger.w(
        'Error loading notifications (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );

      unreadNotificationCount = notifications.where((n) => !n.isRead).length;
    }
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

  Future<void> respondToInvitation(String invitationId, bool accept) async {
    try {
      final response = accept ? 'accepted' : 'declined';
      await _teamService!.respondToInvitation(invitationId, response);

      pendingInvitations.removeWhere((inv) => inv.id == invitationId);

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

    logger.d(
      'Organized tasks: ${personalTasks.length} personal, ${teamTasks.length} team',
    );
  }

  void _filterCurrentTasks() {
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

  // Fixed createTask method in TaskDatabase class
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
      logger.i(
        'TaskDatabase.createTask called with: name=$name, teamId=$teamId, priority=$priority',
      );

      if (_taskService == null) {
        logger.e('TaskService is not initialized');
        throw Exception('Task service not initialized');
      }

      String? validTeamId;
      if (teamId != null && teamId.isNotEmpty) {
        final team = userTeams.firstWhere(
          (t) => t.id == teamId,
          orElse: () => throw Exception('Selected team not found'),
        );
        validTeamId = team.id;
        logger.i('Using valid team ID: $validTeamId');
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

      logger.i('Task created successfully via service: ${task.id}');

      if (task.isTeamTask && validTeamId != null) {
        teamTasks.add(task);
        logger.i('Added to team tasks list');
      } else {
        personalTasks.add(task);
        logger.i('Added to personal tasks list');
      }

      currentTasks.add(task);

      _organizeTasksByType();
      logger.i('Local task lists updated, notifying listeners');
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 500), () {
        _loadTasks().catchError((e) {
          logger.w('Background task refresh failed (non-critical): $e');
        });
      });

      return task;
    } catch (e, stackTrace) {
      logger.e(
        'Error in TaskDatabase.createTask',
        error: e,
        stackTrace: stackTrace,
      );

      String userMessage;
      if (e.toString().contains('Task service not initialized')) {
        userMessage = 'App not ready - please restart and try again';
      } else if (e.toString().contains('Selected team not found')) {
        userMessage = 'Selected team is no longer available';
      } else if (e.toString().contains('Network error')) {
        userMessage = 'Network error - check your connection';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Request timeout - please try again';
      } else if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        userMessage = 'Session expired - please login again';
      } else if (e.toString().contains('403') ||
          e.toString().contains('permission')) {
        userMessage = 'Permission denied - you may not be a team member';
      } else {
        userMessage =
            'Failed to create task: ${e.toString().replaceFirst('Exception: ', '')}';
      }

      throw Exception(userMessage);
    }
  }

  // FIXED: Complete task with proper state management
  Future<void> completeTask(String taskId, bool isCompleted) async {
    try {
      logger.i('TaskDatabase.completeTask: $taskId, completed: $isCompleted');

      if (_taskService == null) {
        throw Exception('Task service not initialized');
      }

      final updatedTask = await _taskService!.completeTask(taskId, isCompleted);
      logger.i('Task completion API call successful: ${updatedTask.id}');

      bool taskFound = false;

      for (int i = 0; i < currentTasks.length; i++) {
        if (currentTasks[i].id == taskId) {
          currentTasks[i] = updatedTask;
          taskFound = true;
          logger.d('Updated task in currentTasks at index $i');
          break;
        }
      }

      for (int i = 0; i < personalTasks.length; i++) {
        if (personalTasks[i].id == taskId) {
          personalTasks[i] = updatedTask;
          logger.d('Updated task in personalTasks at index $i');
          break;
        }
      }

      for (int i = 0; i < teamTasks.length; i++) {
        if (teamTasks[i].id == taskId) {
          teamTasks[i] = updatedTask;
          logger.d('Updated task in teamTasks at index $i');
          break;
        }
      }

      if (!taskFound) {
        logger.w('Task $taskId not found in local lists, refreshing all tasks');
        await _loadTasks();
      } else {
        _organizeTasksByType();
        logger.i('Task completion state updated successfully');
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

      if (e.toString().contains('Network error')) {
        userMessage = 'Network error - check your connection';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Request timeout - please try again';
      } else if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
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
      await _widgetService.updateWidgetWithHistoricalData(
        _historicalCompletions,
        currentTasks,
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

  // Local, instant stats calculator (reactive in UI)
  Map<String, int> calculateDashboardStats() {
    final now = DateTime.now();

    final completedToday = currentTasks.where((task) {
      return task.isCompletedToday();
    }).length;

    final overdueTasks = currentTasks.where((task) {
      return task.dueDate != null &&
          task.dueDate!.isBefore(now) &&
          !task.isCompletedToday();
    }).length;

    final upcomingTasks = currentTasks.where((task) {
      return task.dueDate != null &&
          task.dueDate!.isAfter(now) &&
          !task.isCompletedToday();
    }).length;

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
