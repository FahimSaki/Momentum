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

  // Services
  TaskApiService? _apiService;
  final WidgetService _widgetService = WidgetService();
  TimerService? _timerService;

  // Getter to expose historical data to UI components
  List<DateTime> get historicalCompletions =>
      List.unmodifiable(_historicalCompletions);

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
    jwtToken = jwt;
    this.userId = userId;

    _apiService = TaskApiService(jwtToken: jwt, userId: userId);

    await _loadHistoricalCompletions();
    await readTasks();

    if (!kIsWeb) {
      _startPolling();
      _scheduleMidnightCleanup();
    }
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
    _timerService?.dispose();
    super.dispose();
  }

  void _scheduleMidnightCleanup() {
    if (kIsWeb) return;
    _timerService?.scheduleMidnightCleanup();
  }

  Future<void> removeYesterdayCompletions() async {
    try {
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
      final tasks = await _apiService?.fetchTasks() ?? [];

      TaskOrganizer.organizeTasks(
        tasks,
        currentTasks,
        activeTasks,
        completedTasks,
      );

      notifyListeners();
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e('Error fetching tasks', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addTask(String taskName) async {
    try {
      lastLocalInsertTime = DateTime.now();
      await _apiService?.createTask(taskName);
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error adding task', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateTaskCompletion(String id, bool isCompleted) async {
    try {
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
      await _apiService?.updateTask(id, {'name': newName});
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error updating task name', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _apiService?.deleteTask(id);
      await _loadHistoricalCompletions();
      await readTasks();
    } catch (e, stackTrace) {
      logger.e('Error deleting task', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteCompletedTasks() async {
    try {
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
