import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:habit_tracker/database/api_service.dart';
import 'package:habit_tracker/database/widget_service.dart';
import 'package:habit_tracker/database/timer_service.dart';
import 'package:habit_tracker/database/completion_helper.dart';
import 'package:habit_tracker/database/db_organizer.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HabitDatabase extends ChangeNotifier {
  final Logger logger = Logger();

  final List<Habit> currentHabits = [];
  final List<Habit> activeHabits = [];
  final List<Habit> completedHabits = [];

  DateTime? _firstLaunchDate;
  DateTime? lastLocalInsertTime;
  RealtimeService? _realtimeService;
  String? jwtToken;
  String? userId;

  // Services
  HabitApiService? _apiService;
  final WidgetService _widgetService = WidgetService();
  TimerService? _timerService;

  HabitDatabase() {
    if (!kIsWeb) {
      _initializeTimerService();
    }
  }

  void _initializeTimerService() {
    _timerService = TimerService(
      onPollingTick: () async => await readHabits(),
      onMidnightCleanup: () async => await removeYesterdayCompletions(),
    );
  }

  Future<void> initialize({required String jwt, required String userId}) async {
    jwtToken = jwt;
    this.userId = userId;

    _apiService = HabitApiService(jwtToken: jwt, userId: userId);
    _firstLaunchDate = await getFirstLaunchDate();
    _realtimeService = RealtimeService();

    if (!kIsWeb) {
      await _realtimeService!.init();
      _initializeTimerService();
    }

    await readHabits();
    _startPolling();

    if (!kIsWeb) {
      _scheduleMidnightCleanup();
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
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error removing yesterday completions',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<DateTime?> getFirstLaunchDate() async {
    if (_firstLaunchDate != null) return _firstLaunchDate;

    try {
      final date = await _apiService?.getFirstLaunchDate();
      if (date != null) {
        _firstLaunchDate = date;
      } else {
        _firstLaunchDate = DateTime.now();
        await _apiService?.setFirstLaunchDate(_firstLaunchDate!);
      }
    } catch (e) {
      _firstLaunchDate = DateTime.now();
    }
    return _firstLaunchDate;
  }

  Future<void> readHabits() async {
    try {
      final habits = await _apiService?.fetchHabits() ?? [];

      HabitOrganizer.organizeHabits(
        habits,
        currentHabits,
        activeHabits,
        completedHabits,
      );

      notifyListeners();
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e('Error fetching habits', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addHabit(String habitName) async {
    try {
      lastLocalInsertTime = DateTime.now();
      await _apiService?.createHabit(habitName);
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error adding habit', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateHabitCompletion(String id, bool isCompleted) async {
    try {
      final habit = currentHabits.firstWhere((h) => h.id == id);
      final updates =
          HabitCompletionHelper.processCompletionToggle(habit, isCompleted);

      if (updates != null) {
        await _apiService?.updateHabit(id, updates);
        await readHabits();
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.e('Error updating habit completion',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateHabitName(String id, String newName) async {
    try {
      await _apiService?.updateHabit(id, {'name': newName});
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error updating habit name', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _apiService?.deleteHabit(id);
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error deleting habit', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteCompletedHabits() async {
    try {
      await _apiService?.deleteCompletedHabits();
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error deleting completed habits',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateWidget() async {
    if (kIsWeb) return;
    await _widgetService.updateWidget(currentHabits);
  }
}
