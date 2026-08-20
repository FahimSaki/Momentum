import 'package:flutter/material.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_invitation.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:momentum/models/pending_task_create.dart';
import 'package:momentum/services/team_service.dart';
import 'package:momentum/services/task_service.dart';
import 'package:momentum/services/notification_service.dart';
import 'package:momentum/database/widget_service.dart';
import 'package:momentum/database/timer_service.dart';
import 'package:momentum/database/local_cache_service.dart';
import 'package:momentum/database/sync_queue_service.dart';
import 'package:momentum/utils/network_utils.dart';
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

  // Dashboard stats — populated from backend, team-scoped when a team is selected.
  // Updated during initialize(), _refreshData(), selectTeam(), and after
  // every task mutation so the numbers stay current.
  Map<String, int> dashboardStats = {
    'totalTasks': 0,
    'completedToday': 0,
    'overdueTasks': 0,
    'upcomingTasks': 0,
  };

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

  // Offline support
  final LocalCacheService _cacheService = LocalCacheService();
  final SyncQueueService _syncQueueService = SyncQueueService();
  bool _isOffline = false;

  bool _isInitialized = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<DateTime> get historicalCompletions =>
      List.unmodifiable(_historicalCompletions);
  bool get isInitialized => _isInitialized;

  /// True when the most recent data fetch had to fall back to cached data
  /// because the network was unreachable.
  bool get isOffline => _isOffline;

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

  // ── Constructor ───────────────────────────────────────────────────────────

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

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({required String jwt, required String userId}) async {
    // Guards against a corrupted/undecryptable secure-storage read that
    // returns an empty string instead of null or a thrown error (see
    // AuthService.getStoredAuthData). An empty jwt here would silently
    // configure every service with 'Authorization: Bearer ' and the
    // backend would reject every call with 401 "Access token required"
    // instead of us cleanly detecting "no usable session" up front.
    if (jwt.isEmpty || userId.isEmpty) {
      throw Exception(
        'Cannot initialize session with an empty token or user id',
      );
    }

    try {
      logger.i('Initializing TaskDatabase with userId: $userId');

      jwtToken = jwt;
      this.userId = userId;

      _teamService = TeamService(jwtToken: jwt);
      _taskService = TaskService(jwtToken: jwt);

      if (!kIsWeb) {
        await _notificationService?.init(jwtToken: jwt);
      }

      // Replay anything queued from a previous offline session before we
      // fetch fresh data, so a successfully-synced task shows up as synced
      // rather than as a stale local placeholder.
      await _flushPendingOperations();

      await Future.wait([
        _loadUserTeams(),
        _loadPendingInvitations(),
        _loadTasks(),
        _loadHistoricalCompletions(),
        _loadNotifications(),
        _loadDashboardStats(),
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

  Future<void> clearData() async {
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
    dashboardStats = {
      'totalTasks': 0,
      'completedToday': 0,
      'overdueTasks': 0,
      'upcomingTasks': 0,
    };
    jwtToken = null;
    userId = null;
    _teamService = null;
    _taskService = null;
    _isInitialized = false;
    _isOffline = false;
    await _cacheService.clearAll();
    await _syncQueueService.clear();
    notifyListeners();
  }

  // ── Private loaders ───────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    try {
      if (_taskService == null) return;

      List<Task> tasks = [];
      if (selectedTeam != null) {
        tasks = await _taskService!.getTeamTasks(selectedTeam!.id);
      } else {
        tasks = await _taskService!.getUserTasks();
      }

      // Backend already returns the active set (status=active by default).
      // The local filter below is a safety net — it mirrors the server rule so
      // any edge-case tasks that slip through are still handled correctly.
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
      _isOffline = false;
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);
      notifyListeners();
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        logger.w('Offline — showing cached tasks');
        final cached = await _cacheService.loadTasks(selectedTeam?.id);
        currentTasks.clear();
        currentTasks.addAll(cached);
        _organizeTasksByType();
        _isOffline = true;
        notifyListeners();
      } else {
        logger.e('Error loading tasks', error: e, stackTrace: stackTrace);
      }
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
      await _cacheService.saveTeams(userTeams);
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        logger.w('Offline — showing cached teams');
        final cached = await _cacheService.loadTeams();
        userTeams.clear();
        userTeams.addAll(cached);
        _isOffline = true;
      } else {
        logger.e('Error loading user teams', error: e, stackTrace: stackTrace);
      }
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

  Future<void> _loadHistoricalCompletions() async {
    try {
      final historicalData =
          await _taskService?.getTaskHistory(teamId: selectedTeam?.id) ?? [];
      _historicalCompletions.clear();
      _historicalCompletions.addAll(historicalData);
      await _cacheService.saveHistoricalCompletions(
        selectedTeam?.id,
        _historicalCompletions,
      );
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        final cached = await _cacheService.loadHistoricalCompletions(
          selectedTeam?.id,
        );
        _historicalCompletions.clear();
        _historicalCompletions.addAll(cached);
        _isOffline = true;
      } else {
        logger.w(
          'Could not load historical completions (non-critical)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Fetches dashboard stats from the backend, scoped to the selected team.
  /// Called during init, refresh, team switch, and after task mutations.
  Future<void> _loadDashboardStats() async {
    try {
      if (_taskService == null) return;
      final stats = await _taskService!.getDashboardStats(
        teamId: selectedTeam?.id,
      );
      dashboardStats = stats;
      await _cacheService.saveDashboardStats(selectedTeam?.id, stats);
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        final cached = await _cacheService.loadDashboardStats(selectedTeam?.id);
        if (cached != null) dashboardStats = cached;
        _isOffline = true;
      } else {
        logger.w(
          'Could not load dashboard stats (non-critical)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  // ── Team operations ───────────────────────────────────────────────────────

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

  Future<void> removeTeamMember(String teamId, String memberId) async {
    try {
      await _teamService!.removeTeamMember(teamId, memberId);
      await _loadUserTeams();
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
    // Reload stats scoped to the newly selected team (or personal if null)
    _loadDashboardStats().catchError(
      (e) => logger.w('Dashboard stats update failed after team switch: $e'),
    );
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

  // ── Task operations ───────────────────────────────────────────────────────

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
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);
      notifyListeners();

      // Refresh task list in background after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadTasks().catchError(
          (e) => logger.w('Background task refresh failed: $e'),
        );
      });

      // Update dashboard stats from backend (fire-and-forget)
      _loadDashboardStats().catchError(
        (e) => logger.w('Dashboard stats update failed after createTask: $e'),
      );

      return task;
    } catch (e, stackTrace) {
      // Personal tasks (no team) can be created offline and synced later.
      // Team tasks always need the server, since membership/permissions
      // have to be checked there.
      final isPersonalTask = teamId == null || teamId.isEmpty;
      if (isPersonalTask && isNetworkError(e)) {
        return _createTaskOffline(
          name: name.trim(),
          description: description?.trim(),
          assignedTo: assignedTo,
          priority: priority,
          dueDate: dueDate,
          tags: tags ?? [],
          assignmentType: assignmentType,
        );
      }

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
      } else if (isNetworkError(e)) {
        userMessage = 'Network error - check your connection';
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

  /// Saves a personal task locally with a placeholder id and queues it to
  /// be created on the server once the connection is back.
  Future<Task> _createTaskOffline({
    required String name,
    String? description,
    List<String>? assignedTo,
    required String priority,
    DateTime? dueDate,
    required List<String> tags,
    required String assignmentType,
  }) async {
    final localId = Task.generateLocalId();
    final now = DateTime.now();

    final placeholder = Task(
      id: localId,
      name: name,
      description: description,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
      isTeamTask: false,
      assignmentType: assignmentType,
      createdAt: now,
      updatedAt: now,
      syncStatus: TaskSyncStatus.pendingCreate,
    );

    currentTasks.add(placeholder);
    _organizeTasksByType();
    _isOffline = true;

    await _syncQueueService.enqueue(
      PendingTaskCreate(
        localId: localId,
        name: name,
        description: description,
        assignedTo: assignedTo,
        teamId: null,
        priority: priority,
        dueDate: dueDate,
        tags: tags,
        assignmentType: assignmentType,
        queuedAt: now,
      ),
    );
    await _cacheService.saveTasks(null, currentTasks);

    logger.i('No connection — queued "$name" to sync when back online');
    notifyListeners();
    return placeholder;
  }

  /// Replays queued personal-task creations. Called before every load
  /// (initialize, polling tick, manual refresh) so a reconnect gets picked
  /// up automatically without any action from the user.
  ///
  /// Guarded against overlapping calls: a polling tick firing while a
  /// manual pull-to-refresh is still in flight (or two ticks overlapping
  /// because the first is still waiting on a slow/just-woken backend)
  /// previously meant two independent runs of this method could both read
  /// the same queued item before either removed it, and both POST it —
  /// creating two real tasks on the server from one offline creation. Any
  /// caller that arrives while a flush is already running now awaits that
  /// same attempt instead of starting a second one.
  Future<void>? _pendingFlushFuture;

  Future<void> _flushPendingOperations() {
    final inFlight = _pendingFlushFuture;
    if (inFlight != null) return inFlight;

    final flush = _flushPendingOperationsOnce();
    _pendingFlushFuture = flush;
    return flush.whenComplete(() => _pendingFlushFuture = null);
  }

  Future<void> _flushPendingOperationsOnce() async {
    if (_taskService == null) return;
    final pending = await _syncQueueService.getPending();
    if (pending.isEmpty) return;

    bool changed = false;
    bool stillOffline = false;

    for (final op in pending) {
      try {
        // clientId (the placeholder's local id) lets the backend recognise
        // a retry of this exact operation — e.g. this same attempt already
        // succeeded server-side once but the client never saw the response
        // (timed out waiting on a Render free-tier instance waking up) —
        // and hand back the existing task instead of creating another one.
        final synced = await _taskService!.createTask(
          name: op.name,
          description: op.description,
          assignedTo: op.assignedTo,
          teamId: op.teamId,
          priority: op.priority,
          dueDate: op.dueDate,
          tags: op.tags,
          assignmentType: op.assignmentType,
          clientId: op.localId,
        );

        final index = currentTasks.indexWhere((t) => t.id == op.localId);
        if (index != -1) {
          currentTasks[index] = synced;
        } else {
          currentTasks.add(synced);
        }

        await _syncQueueService.remove(op.localId);
        changed = true;
        logger.i('Synced offline task ${op.localId} -> ${synced.id}');
      } catch (e) {
        if (isNetworkError(e)) {
          // Still offline — leave the rest queued and try again next tick.
          stillOffline = true;
          break;
        }
        // The server actively rejected it (validation, etc.) — don't
        // retry forever, just flag it so the user can see and re-create it.
        logger.w('Server rejected queued task "${op.name}": $e');
        final index = currentTasks.indexWhere((t) => t.id == op.localId);
        if (index != -1) {
          currentTasks[index].syncStatus = TaskSyncStatus.syncFailed;
        }
        await _syncQueueService.remove(op.localId);
        changed = true;
      }
    }

    if (!stillOffline) _isOffline = false;
    if (changed) {
      _organizeTasksByType();
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);
      notifyListeners();
    }
  }

  Future<void> completeTask(String taskId, bool isCompleted) async {
    if (Task.isLocalId(taskId)) {
      throw Exception(
        "This task hasn't finished syncing yet — try again in a moment",
      );
    }
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
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);

      // Update dashboard stats from backend (fire-and-forget)
      _loadDashboardStats().catchError(
        (e) => logger.w('Dashboard stats update failed after completeTask: $e'),
      );

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
      if (isNetworkError(e)) {
        userMessage = 'Network error - check your connection';
      } else if (msg.contains('401') || msg.contains('unauthorized')) {
        userMessage = 'Session expired - please login again';
      }
      throw Exception(userMessage);
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    if (Task.isLocalId(taskId)) {
      throw Exception(
        "This task hasn't finished syncing yet — try again in a moment",
      );
    }
    try {
      final updatedTask = await _taskService!.updateTask(taskId, updates);
      final index = currentTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        currentTasks[index] = updatedTask;
        _organizeTasksByType();
        await updateWidget();
        await _cacheService.saveTasks(selectedTeam?.id, currentTasks);
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (Task.isLocalId(taskId)) {
      // Never reached the server — just drop it locally and out of the
      // sync queue, no network call needed.
      currentTasks.removeWhere((t) => t.id == taskId);
      personalTasks.removeWhere((t) => t.id == taskId);
      teamTasks.removeWhere((t) => t.id == taskId);
      await _syncQueueService.remove(taskId);
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);
      notifyListeners();
      return;
    }
    try {
      await _taskService!.deleteTask(taskId);
      currentTasks.removeWhere((t) => t.id == taskId);
      _organizeTasksByType();
      await _loadHistoricalCompletions();
      await updateWidget();
      await _cacheService.saveTasks(selectedTeam?.id, currentTasks);

      // Update dashboard stats from backend (fire-and-forget)
      _loadDashboardStats().catchError(
        (e) => logger.w('Dashboard stats update failed after deleteTask: $e'),
      );

      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── Notification operations ───────────────────────────────────────────────

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      // Use the backend-returned notification so readAt reflects server time,
      // not the client clock. Fall back to a local update if parsing fails.
      final updated = await _notificationService?.markAsRead(notificationId);

      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        if (updated != null) {
          notifications[index] = updated;
        } else {
          // Fallback: construct locally with client timestamp
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
        }
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

  // ── Timer / polling ───────────────────────────────────────────────────────

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
      await _flushPendingOperations();
      await Future.wait([
        _loadTasks(),
        _loadNotifications(),
        _loadPendingInvitations(),
        _loadDashboardStats(),
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
      await _loadDashboardStats();
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e(
        'Error handling midnight cleanup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Public helpers ────────────────────────────────────────────────────────

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

  /// Legacy async fetch — kept for backward compatibility.
  /// Prefer reading [dashboardStats] directly; it is always populated.
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

  /// Synchronous stats computed from the in-memory task list.
  /// Used internally as a fallback; the widget reads [dashboardStats] instead.
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
