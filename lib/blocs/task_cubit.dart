import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:momentum/blocs/notification_cubit.dart';
import 'package:momentum/blocs/session_cubit.dart';
import 'package:momentum/blocs/task_state.dart';
import 'package:momentum/blocs/team_cubit.dart';
import 'package:momentum/blocs/team_state.dart';
import 'package:momentum/database/local_cache_service.dart';
import 'package:momentum/database/sync_queue_service.dart';
import 'package:momentum/database/timer_service.dart';
import 'package:momentum/database/widget_service.dart';
import 'package:momentum/models/pending_task_create.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/services/push_notification_service.dart';
import 'package:momentum/services/task_service.dart';
import 'package:momentum/utils/network_utils.dart';

/// Owns tasks, historical completions, dashboard stats, the offline sync
/// queue, and the overall session init/refresh/clear orchestration.
///
/// Takes NotificationCubit, TeamCubit, and SessionCubit as direct
/// constructor references and listens to TeamCubit.stream for
/// selection changes.
class TaskCubit extends Cubit<TaskState> {
  final Logger _logger = Logger();
  final WidgetService _widgetService = WidgetService();
  final LocalCacheService _cacheService = LocalCacheService();
  final SyncQueueService _syncQueueService = SyncQueueService();

  // Handles FCM/local-notification setup for this session.
  // NotificationCubit owns a separate NotificationService instance for
  // the REST notification list.
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  TaskService? _taskService;
  TimerService? _timerService;

  final NotificationCubit _notificationCubit;
  final TeamCubit _teamCubit;
  final SessionCubit _sessionCubit;
  StreamSubscription<TeamState>? _teamSubscription;

  TaskCubit({
    required NotificationCubit notificationCubit,
    required TeamCubit teamCubit,
    required SessionCubit sessionCubit,
  }) : _notificationCubit = notificationCubit,
       _teamCubit = teamCubit,
       _sessionCubit = sessionCubit,
       super(const TaskState()) {
    _timerService = TimerService(
      onPollingTick: () async => await refreshData(),
      onMidnightCleanup: () async => await _handleMidnightCleanup(),
    );

    _teamSubscription = teamCubit.stream.listen((teamState) {
      if (teamState.selectedTeam?.id != state.selectedTeam?.id) {
        _onTeamChanged(teamState.selectedTeam);
      }
    });
  }

  // ── Session ─────────────────────────────────────────────────────────────

  Future<void> initializeSession({
    required String jwt,
    required String userId,
  }) async {
    if (jwt.isEmpty || userId.isEmpty) {
      throw Exception(
        'Cannot initialize session with an empty token or user id',
      );
    }

    try {
      _logger.i('Initializing TaskCubit with userId: $userId');

      _taskService = TaskService(jwtToken: jwt);

      _notificationCubit.setToken(jwt);
      _teamCubit.setToken(jwt);
      _sessionCubit.setSession(jwtToken: jwt, userId: userId);

      await _pushNotificationService.init(jwtToken: jwt);

      await _flushPendingOperations();

      await Future.wait([
        _teamCubit.loadTeamsAndInvitations(),
        _loadTasks(),
        _loadHistoricalCompletions(),
        _notificationCubit.loadNotifications(),
        _loadDashboardStats(),
      ]);

      if (!kIsWeb) {
        _timerService?.startPolling();
        _timerService?.scheduleMidnightCleanup();
      }

      await updateWidget();
      emit(state.copyWith(isInitialized: true));
      _logger.i('TaskCubit initialization complete');
    } catch (e, stackTrace) {
      _logger.e(
        'TaskCubit initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(isInitialized: false));
      rethrow;
    }
  }

  Future<void> clearData() async {
    _logger.i('Clearing TaskCubit data');
    _notificationCubit.clear();
    _teamCubit.clear();
    _sessionCubit.clear();
    emit(const TaskState());
    _taskService = null;
    await _cacheService.clearAll();
    await _syncQueueService.clear();
  }

  // ── Loaders ─────────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    try {
      if (_taskService == null) return;

      List<Task> tasks = [];
      if (state.selectedTeam != null) {
        tasks = await _taskService!.getTeamTasks(state.selectedTeam!.id);
      } else {
        tasks = await _taskService!.getUserTasks();
      }

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

      emit(state.copyWith(currentTasks: filtered, isOffline: false));
      await _cacheService.saveTasks(state.selectedTeam?.id, filtered);
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        _logger.w('Offline — showing cached tasks');
        final cached = await _cacheService.loadTasks(state.selectedTeam?.id);
        emit(state.copyWith(currentTasks: cached, isOffline: true));
      } else {
        _logger.e('Error loading tasks', error: e, stackTrace: stackTrace);
      }
    }
  }

  Future<void> _loadHistoricalCompletions() async {
    try {
      final historicalData =
          await _taskService?.getTaskHistory(teamId: state.selectedTeam?.id) ??
          [];
      emit(state.copyWith(historicalCompletions: historicalData));
      await _cacheService.saveHistoricalCompletions(
        state.selectedTeam?.id,
        historicalData,
      );
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        final cached = await _cacheService.loadHistoricalCompletions(
          state.selectedTeam?.id,
        );
        emit(state.copyWith(historicalCompletions: cached, isOffline: true));
      } else {
        _logger.w(
          'Could not load historical completions (non-critical)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      if (_taskService == null) return;
      final stats = await _taskService!.getDashboardStats(
        teamId: state.selectedTeam?.id,
      );
      emit(state.copyWith(dashboardStats: stats));
      await _cacheService.saveDashboardStats(state.selectedTeam?.id, stats);
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        final cached = await _cacheService.loadDashboardStats(
          state.selectedTeam?.id,
        );
        emit(
          state.copyWith(
            dashboardStats: cached ?? state.dashboardStats,
            isOffline: true,
          ),
        );
      } else {
        _logger.w(
          'Could not load dashboard stats (non-critical)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  // ── Team selection ──────────────────────────────────────────────────────

  Future<void> _onTeamChanged(Team? team) async {
    emit(
      TaskState(
        currentTasks: const [],
        historicalCompletions: state.historicalCompletions,
        dashboardStats: state.dashboardStats,
        selectedTeam: team,
        isOffline: state.isOffline,
        isInitialized: state.isInitialized,
      ),
    );
    await _loadTasks();
    await _loadDashboardStats().catchError(
      (e) => _logger.w('Dashboard stats update failed after team switch: $e'),
    );
  }

  // ── Task mutations ──────────────────────────────────────────────────────

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
        validTeamId = teamId;
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

      final updatedTasks = [...state.currentTasks, task];
      emit(state.copyWith(currentTasks: updatedTasks));

      await updateWidget();
      await _cacheService.saveTasks(state.selectedTeam?.id, updatedTasks);

      Future.delayed(const Duration(milliseconds: 500), () {
        _loadTasks().catchError(
          (e) => _logger.w('Background task refresh failed: $e'),
        );
      });
      _loadDashboardStats().catchError(
        (e) => _logger.w('Dashboard stats update failed after createTask: $e'),
      );

      return task;
    } catch (e, stackTrace) {
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

      _logger.e(
        'Error in TaskCubit.createTask',
        error: e,
        stackTrace: stackTrace,
      );
      String userMessage;
      final msg = e.toString();
      if (msg.contains('Task service not initialized')) {
        userMessage = 'App not ready - please restart and try again';
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

    final updatedTasks = [...state.currentTasks, placeholder];
    emit(state.copyWith(currentTasks: updatedTasks, isOffline: true));

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
    await _cacheService.saveTasks(null, updatedTasks);

    _logger.i('No connection — queued "$name" to sync when back online');
    return placeholder;
  }

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

    var tasks = List<Task>.from(state.currentTasks);
    bool changed = false;
    bool stillOffline = false;

    for (final op in pending) {
      try {
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

        final index = tasks.indexWhere((t) => t.id == op.localId);
        if (index != -1) {
          tasks[index] = synced;
        } else {
          tasks.add(synced);
        }

        await _syncQueueService.remove(op.localId);
        changed = true;
        _logger.i('Synced offline task ${op.localId} -> ${synced.id}');
      } catch (e) {
        if (isNetworkError(e)) {
          stillOffline = true;
          break;
        }
        _logger.w('Server rejected queued task "${op.name}": $e');
        final index = tasks.indexWhere((t) => t.id == op.localId);
        if (index != -1) {
          tasks[index].syncStatus = TaskSyncStatus.syncFailed;
        }
        await _syncQueueService.remove(op.localId);
        changed = true;
      }
    }

    if (changed) {
      emit(
        state.copyWith(
          currentTasks: tasks,
          isOffline: stillOffline ? state.isOffline : false,
        ),
      );
      await _cacheService.saveTasks(state.selectedTeam?.id, tasks);
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

      final index = state.currentTasks.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        await _loadTasks();
      } else {
        final updatedTasks = List<Task>.from(state.currentTasks);
        updatedTasks[index] = updatedTask;
        emit(state.copyWith(currentTasks: updatedTasks));
      }

      await updateWidget();
      await _cacheService.saveTasks(state.selectedTeam?.id, state.currentTasks);

      _loadDashboardStats().catchError(
        (e) =>
            _logger.w('Dashboard stats update failed after completeTask: $e'),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error in TaskCubit.completeTask',
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
      final index = state.currentTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final updatedTasks = List<Task>.from(state.currentTasks);
        updatedTasks[index] = updatedTask;
        emit(state.copyWith(currentTasks: updatedTasks));
        await updateWidget();
        await _cacheService.saveTasks(state.selectedTeam?.id, updatedTasks);
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (Task.isLocalId(taskId)) {
      final updatedTasks = state.currentTasks
          .where((t) => t.id != taskId)
          .toList();
      emit(state.copyWith(currentTasks: updatedTasks));
      await _syncQueueService.remove(taskId);
      await _cacheService.saveTasks(state.selectedTeam?.id, updatedTasks);
      return;
    }
    try {
      await _taskService!.deleteTask(taskId);
      final updatedTasks = state.currentTasks
          .where((t) => t.id != taskId)
          .toList();
      emit(state.copyWith(currentTasks: updatedTasks));
      await _loadHistoricalCompletions();
      await updateWidget();
      await _cacheService.saveTasks(state.selectedTeam?.id, updatedTasks);

      _loadDashboardStats().catchError(
        (e) => _logger.w('Dashboard stats update failed after deleteTask: $e'),
      );
    } catch (e, stackTrace) {
      _logger.e('Error deleting task', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── Refresh / midnight cleanup ──────────────────────────────────────────

  Future<void> refreshData() async {
    try {
      if (!state.isInitialized) return;
      await _flushPendingOperations();
      await Future.wait([
        _loadTasks(),
        _notificationCubit.loadNotifications(),
        _teamCubit.loadPendingInvitations(),
        _loadDashboardStats(),
      ]);
      await updateWidget();
    } catch (e, stackTrace) {
      _logger.e('Error refreshing data', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _handleMidnightCleanup() async {
    try {
      if (!state.isInitialized) return;
      await _loadHistoricalCompletions();
      await _loadTasks();
      await _loadDashboardStats();
      await updateWidget();
    } catch (e, stackTrace) {
      _logger.e(
        'Error handling midnight cleanup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Public helpers ──────────────────────────────────────────────────────

  /// Public — InitializationService calls this directly after completing
  /// a task via the home-screen-widget tap action, to refresh the widget
  /// immediately. Do not make this private.
  Future<void> updateWidget() async {
    if (kIsWeb) return;
    try {
      await _widgetService.updateWidgetWithHistoricalData(
        state.historicalCompletions,
        state.currentTasks,
        selectedTeam: state.selectedTeam,
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }

  Future<Map<String, int>> getDashboardStats() async {
    try {
      return await _taskService?.getDashboardStats(
            teamId: state.selectedTeam?.id,
          ) ??
          {
            'totalTasks': 0,
            'completedToday': 0,
            'overdueTasks': 0,
            'upcomingTasks': 0,
          };
    } catch (e, stackTrace) {
      _logger.e(
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
    final completedToday = state.currentTasks
        .where((task) => task.isCompletedToday())
        .length;
    final overdueTasks = state.currentTasks
        .where(
          (task) =>
              task.dueDate != null &&
              task.dueDate!.isBefore(now) &&
              !task.isCompletedToday(),
        )
        .length;
    final upcomingTasks = state.currentTasks
        .where(
          (task) =>
              task.dueDate != null &&
              task.dueDate!.isAfter(now) &&
              !task.isCompletedToday(),
        )
        .length;

    return {
      'totalTasks': state.currentTasks.length,
      'completedToday': completedToday,
      'overdueTasks': overdueTasks,
      'upcomingTasks': upcomingTasks,
    };
  }

  @override
  Future<void> close() {
    _teamSubscription?.cancel();
    _timerService?.dispose();
    return super.close();
  }
}
