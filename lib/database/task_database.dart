import 'package:flutter/material.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/database/api_service.dart';
import 'package:momentum/database/widget_service.dart';
import 'package:momentum/database/timer_service.dart';
import 'package:momentum/database/completion_helper.dart';
import 'package:momentum/database/db_organizer.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TaskDatabase extends ChangeNotifier {
  final Logger logger = Logger();

  final List<Task> currentTasks = [];
  final List<Task> activeTasks = [];
  final List<Task> completedTasks = [];

  final List<DateTime> _historicalCompletions = [];

  DateTime? lastLocalInsertTime;
  String? jwtToken;
  String? userId;
  bool _isInitialized = false;

  // Services
  TaskApiService? _apiService;
  final WidgetService _widgetService = WidgetService();
  TimerService? _timerService;

  // Getter to expose historical data to UI components
  List<DateTime> get historicalCompletions =>
      List.unmodifiable(_historicalCompletions);

  // Check if database is initialized
  bool get isInitialized => _isInitialized;

  TaskDatabase() {
    if (!kIsWeb) {
      _initializeTimerService();
    }
  }

  void _initializeTimerService() {
    _timerService = TimerService(
      onPollingTick: () async => await readTasks(),
      onMidnightCleanup: () async => await removeYesterdayCompletions(),
    );
  }

  Future<void> initialize({required String jwt, required String userId}) async {
    try {
      logger.i('Initializing TaskDatabase with userId: $userId');

      jwtToken = jwt;
      this.userId = userId;

      _apiService = TaskApiService(jwtToken: jwt, userId: userId);

      // Load data
      await _loadHistoricalCompletions();
      await readTasks();

      // Only start polling/cleanup on mobile
      if (!kIsWeb) {
        _startPolling();
        _scheduleMidnightCleanup();
      }

      _isInitialized = true;
      logger.i('TaskDatabase initialization complete');
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('TaskDatabase initialization failed',
          error: e, stackTrace: stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  // Method to clear data without disposing (for logout)
  void clearData() {
    logger.i('Clearing TaskDatabase data');
    currentTasks.clear();
    activeTasks.clear();
    completedTasks.clear();
    _historicalCompletions.clear();

    jwtToken = null;
    userId = null;
    _apiService = null;
    _isInitialized = false;

    notifyListeners();
  }

  Future<void> _loadHistoricalCompletions() async {
    try {
      final historicalData =
          await _apiService?.fetchHistoricalCompletions() ?? [];
      _historicalCompletions.clear();
      _historicalCompletions.addAll(historicalData);
      logger
          .i('Loaded ${_historicalCompletions.length} historical completions');

      notifyListeners();
    } catch (e, stackTrace) {
      logger.w('Could not load historical completions (non-critical)',
          error: e, stackTrace: stackTrace);
    }
  }

  void _startPolling() {
    if (kIsWeb) {
      logger.w('Polling disabled on web to reduce CPU load');
      return;
    }
    _timerService?.startPolling();
  }

  @override
  void dispose() {
    logger.i('Disposing TaskDatabase');
    _timerService?.dispose();
    super.dispose();
  }

  void _scheduleMidnightCleanup() {
    if (kIsWeb) return;
    _timerService?.scheduleMidnightCleanup();
  }

  Future<void> removeYesterdayCompletions() async {
    try {
      if (!_isInitialized) {
        logger.w(
            'TaskDatabase not initialized, skipping removeYesterdayCompletions');
        return;
      }

      await _apiService?.removeYesterdayCompletions();
      await _loadHistoricalCompletions();
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error removing yesterday completions',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> readTasks() async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, skipping readTasks');
        return;
      }

      logger.d('Reading tasks from API');
      final tasks = await _apiService?.fetchTasks() ?? [];

      TaskOrganizer.organizeTasks(
        tasks,
        currentTasks,
        activeTasks,
        completedTasks,
      );

      logger.d(
          'Organized ${tasks.length} tasks into ${currentTasks.length} current, ${activeTasks.length} active, ${completedTasks.length} completed');

      notifyListeners();
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e('Error fetching tasks', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addTask(String taskName) async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, cannot add task');
        return;
      }

      lastLocalInsertTime = DateTime.now();
      await _apiService?.createTask(taskName);
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error adding task', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateTaskCompletion(String id, bool isCompleted) async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, cannot update task completion');
        return;
      }

      final task = currentTasks.firstWhere((h) => h.id == id);
      final updates =
          TaskCompletionHelper.processCompletionToggle(task, isCompleted);

      if (updates != null) {
        await _apiService?.updateTask(id, updates);
        await readTasks();
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e('Error updating task completion',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateTaskName(String id, String newName) async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, cannot update task name');
        return;
      }

      await _apiService?.updateTask(id, {'name': newName});
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error updating task name', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, cannot delete task');
        return;
      }

      await _apiService?.deleteTask(id);
      await _loadHistoricalCompletions();
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error deleting task', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteCompletedTasks() async {
    try {
      if (!_isInitialized) {
        logger.w('TaskDatabase not initialized, cannot delete completed tasks');
        return;
      }

      await _apiService?.deleteCompletedTasks();
      await _loadHistoricalCompletions();
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error deleting completed tasks',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateWidget() async {
    if (kIsWeb) return;
    await _widgetService.updateWidgetWithHistoricalData(
        _historicalCompletions, currentTasks);
  }
}
