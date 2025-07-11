import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:logger/logger.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HabitDatabase extends ChangeNotifier {
  final Logger logger = Logger();
  final List<Habit> currentHabits = [];
  DateTime? _firstLaunchDate;
  DateTime? lastLocalInsertTime;
  RealtimeService? _realtimeService;
  Timer? _pollingTimer;
  String? jwtToken;
  String? userId;

  Timer? _midnightTimer;

  HabitDatabase() {
    // No realtime subscription
    _scheduleMidnightCleanup();
  }

  // Initialize the database and set up polling
  Future<void> initialize({required String jwt, required String userId}) async {
    this.jwtToken = jwt;
    this.userId = userId;
    _realtimeService = RealtimeService();
    await _realtimeService!.init();
    await readHabits();
    _startPolling();
    _scheduleMidnightCleanup();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await readHabits();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // Schedule a timer to trigger at midnight and repeat every 24 hours
  void _scheduleMidnightCleanup() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () async {
      await removeYesterdayCompletions();
      _scheduleMidnightCleanup(); // reschedule for next midnight
    });
  }

  // Call backend to remove yesterday's completions for all habits
  Future<void> removeYesterdayCompletions() async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/habits/remove-yesterday-completions'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error removing yesterday completions: [${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error removing yesterday completions',
          error: e, stackTrace: stackTrace);
    }
  }

  // Get first launch date from backend
  Future<DateTime?> getFirstLaunchDate() async {
    if (_firstLaunchDate != null) return _firstLaunchDate;
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:5000/app_settings/first_launch_date?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _firstLaunchDate = DateTime.parse(data['first_launch_date']);
      } else {
        _firstLaunchDate = DateTime.now();
        await http.post(
          Uri.parse('http://10.0.2.2:5000/app_settings/first_launch_date'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'first_launch_date': _firstLaunchDate!.toIso8601String(),
            'userId': userId
          }),
        );
      }
    } catch (e) {
      _firstLaunchDate = DateTime.now();
    }
    return _firstLaunchDate;
  }

  // Add new habit
  Future<void> addHabit(String habitName) async {
    try {
      lastLocalInsertTime = DateTime.now();
      final deviceId = _realtimeService?.deviceId ?? 'unknown';
      logger.d('Adding habit with device ID: $deviceId');
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/habits'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': habitName,
          'device_id': deviceId,
          'userId': userId,
        }),
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error adding habit: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error adding habit', error: e, stackTrace: stackTrace);
    }
  }

  // Read habits
  Future<void> readHabits() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/habits/assigned?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final habits = data.map((habit) => Habit.fromJson(habit)).toList();
        currentHabits.clear();
        currentHabits.addAll(habits);
        notifyListeners();
        await updateWidget();
      } else {
        logger.e('Error fetching habits: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching habits', error: e, stackTrace: stackTrace);
    }
  }

  // Update habit completion
  Future<void> updateHabitCompletion(String id, bool isCompleted) async {
    try {
      final habit = currentHabits.firstWhere((h) => h.id == id);
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);

      bool changed = false;
      if (isCompleted) {
        // Only add today (UTC) if not already present
        if (!habit.completedDays.any((d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day)) {
          habit.completedDays.add(today);
          habit.lastCompletedDate = today;
          habit.isArchived = true;
          habit.archivedAt = today;
          changed = true;
        }
      } else {
        // Only remove today (UTC), not all completions
        final before = habit.completedDays.length;
        habit.completedDays.removeWhere((d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day);
        if (before != habit.completedDays.length) {
          // If today was removed, update archive fields only if no more today
          final hasToday = habit.completedDays.any((d) =>
              d.toUtc().year == today.year &&
              d.toUtc().month == today.month &&
              d.toUtc().day == today.day);
          if (!hasToday) {
            habit.isArchived = false;
            habit.archivedAt = null;
            // Optionally update lastCompletedDate to most recent, or null
            if (habit.completedDays.isNotEmpty) {
              habit.lastCompletedDate =
                  habit.completedDays.reduce((a, b) => a.isAfter(b) ? a : b);
            } else {
              habit.lastCompletedDate = null;
            }
          }
          changed = true;
        }
      }

      if (changed) {
        final response = await http.put(
          Uri.parse('http://10.0.2.2:5000/habits/$id'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'completedDays':
                habit.completedDays.map((e) => e.toIso8601String()).toList(),
            'lastCompletedDate': habit.lastCompletedDate?.toIso8601String(),
            'isArchived': habit.isArchived,
            'archivedAt': habit.archivedAt?.toIso8601String(),
          }),
        );
        if (response.statusCode == 200) {
          notifyListeners();
        } else {
          logger.e('Error updating habit completion: ${response.body}');
        }
      } else {
        notifyListeners(); // No change, just update UI
      }
    } catch (e, stackTrace) {
      logger.e('Error updating habit completion',
          error: e, stackTrace: stackTrace);
    }
  }

  // Update habit name
  Future<void> updateHabitName(String id, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/habits/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': newName}),
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error updating habit name: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error updating habit name', error: e, stackTrace: stackTrace);
    }
  }

  // Delete habit
  Future<void> deleteHabit(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:5000/habits/$id'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error deleting habit: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error deleting habit', error: e, stackTrace: stackTrace);
    }
  }

  // Delete completed habits older than one day
  Future<void> deleteCompletedHabits() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final response = await http.delete(
        Uri.parse(
            'http://10.0.2.2:5000/habits/completed?before=${yesterday.toIso8601String()}&userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error deleting completed habits: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error deleting completed habits',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateWidget() async {
    try {
      final habits = currentHabits;
      final List<String> widgetData = [];
      final now = DateTime.now();
      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        int completedCount = 0;
        for (final habit in habits) {
          if (habit.completedDays.any((d) =>
              d.year == date.year &&
              d.month == date.month &&
              d.day == date.day)) {
            completedCount++;
          }
        }
        widgetData.add(completedCount.toString());
      }
      await HomeWidget.saveWidgetData('heatmap_data', widgetData.join(','));
      await HomeWidget.updateWidget(
        name: 'MomentumHomeWidget',
        androidName: 'MomentumHomeWidget',
      );
    } catch (e, stackTrace) {
      logger.e('Error updating widget', error: e, stackTrace: stackTrace);
    }
  }
}
