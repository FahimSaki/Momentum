import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:habit_tracker/constants/api_base_url.dart';
import 'package:logger/logger.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:async';

class HabitDatabase extends ChangeNotifier {
  final Logger logger = Logger();

  final List<Habit> currentHabits = [];
  final List<Habit> activeHabits = []; // ✅ NEW
  final List<Habit> completedHabits = []; // ✅ NEW

  DateTime? _firstLaunchDate;
  DateTime? lastLocalInsertTime;
  RealtimeService? _realtimeService;
  Timer? _pollingTimer;
  String? jwtToken;
  String? userId;
  Timer? _midnightTimer;

  HabitDatabase() {
    if (!kIsWeb) {
      _scheduleMidnightCleanup();
    }
  }

  Future<void> initialize({required String jwt, required String userId}) async {
    jwtToken = jwt;
    this.userId = userId;
    _firstLaunchDate = await getFirstLaunchDate();
    _realtimeService = RealtimeService();

    if (!kIsWeb) {
      await _realtimeService!.init();
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

  void _scheduleMidnightCleanup() {
    if (kIsWeb) return;

    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () async {
      await removeYesterdayCompletions();
      _scheduleMidnightCleanup();
    });
  }

  Future<void> removeYesterdayCompletions() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/habits/remove-yesterday-completions'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        await readHabits();
      } else {
        logger.e('Error removing yesterday completions: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error removing yesterday completions',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<DateTime?> getFirstLaunchDate() async {
    if (_firstLaunchDate != null) return _firstLaunchDate;
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/app_settings/first_launch_date?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _firstLaunchDate = DateTime.parse(data['first_launch_date']);
      } else {
        _firstLaunchDate = DateTime.now();
        await http.post(
          Uri.parse('$apiBaseUrl/app_settings/first_launch_date'),
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

  Future<void> readHabits() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/habits/assigned?userId=$userId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final habits = data.map((habit) => Habit.fromJson(habit)).toList();

        final now = DateTime.now();
        final List<Habit> active = [];
        final List<Habit> completed = [];

        for (final habit in habits) {
          if (!habit.isArchived) {
            active.add(habit);
          } else if (habit.archivedAt != null &&
              now.difference(habit.archivedAt!).inHours < 24) {
            completed.add(habit);
          }
        }

        currentHabits
          ..clear()
          ..addAll([...active, ...completed]);

        activeHabits
          ..clear()
          ..addAll(active);

        completedHabits
          ..clear()
          ..addAll(completed);

        notifyListeners();
        await updateWidget();
      } else {
        logger.e('Error fetching habits: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching habits', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addHabit(String habitName) async {
    try {
      lastLocalInsertTime = DateTime.now();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/habits'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': habitName, 'userId': userId}),
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

  Future<void> updateHabitCompletion(String id, bool isCompleted) async {
    try {
      final habit = currentHabits.firstWhere((h) => h.id == id);

      // 🔧 FIXED: Use local midnight converted to UTC
      final localNow = DateTime.now(); // local time
      final today =
          DateTime(localNow.year, localNow.month, localNow.day).toUtc();

      bool changed = false;

      if (isCompleted) {
        // Only add if today's date is not already present
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
        // Remove today's completion
        final before = habit.completedDays.length;
        habit.completedDays.removeWhere((d) =>
            d.toUtc().year == today.year &&
            d.toUtc().month == today.month &&
            d.toUtc().day == today.day);

        if (before != habit.completedDays.length) {
          final hasToday = habit.completedDays.any((d) =>
              d.toUtc().year == today.year &&
              d.toUtc().month == today.month &&
              d.toUtc().day == today.day);
          if (!hasToday) {
            habit.isArchived = false;
            habit.archivedAt = null;

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
          Uri.parse('$apiBaseUrl/habits/$id'),
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
          await readHabits();
          notifyListeners();
        } else {
          logger.e('Error updating habit completion: ${response.body}');
        }
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
      final response = await http.put(
        Uri.parse('$apiBaseUrl/habits/$id'),
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

  Future<void> deleteHabit(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/habits/$id'),
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

  Future<void> deleteCompletedHabits() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final response = await http.delete(
        Uri.parse(
            '$apiBaseUrl/habits/completed?before=${yesterday.toIso8601String()}&userId=$userId'),
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
    if (kIsWeb) return;

    try {
      final habits = currentHabits;
      final List<String> widgetData = [];
      final now = DateTime.now();
      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        int completedCount = 0;
        for (final habit in habits) {
          if (habit.completedDays.any((d) {
            final local = d.toLocal();
            return local.year == date.year &&
                local.month == date.month &&
                local.day == date.day;
          })) {
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
