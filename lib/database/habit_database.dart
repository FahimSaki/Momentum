import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:home_widget/home_widget.dart';

class HabitDatabase extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  final Logger logger = Logger();
  final List<Habit> currentHabits = [];
  DateTime? _firstLaunchDate;
  RealtimeChannel? _habitChannel;
  DateTime? lastLocalInsertTime;

  // Add a reference to RealtimeService
  RealtimeService? _realtimeService;

  HabitDatabase() {
    // Don't set up subscription in constructor
    // This will be called from init()
  }

  // Initialize the database and set up subscriptions
  Future<void> initialize() async {
    // Get RealtimeService instance
    _realtimeService = RealtimeService();
    await _realtimeService!.init();

    // Set up realtime subscription
    _setupRealtimeSubscription();

    // Load initial habits
    await readHabits();
  }

  void _setupRealtimeSubscription() {
    if (_realtimeService == null) return;

    _habitChannel = supabase.channel('public:habits').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'habits',
          callback: (payload) async {
            final habitName = payload.newRecord['name'] as String;
            final createdAt = payload.newRecord['created_at'] as String;
            final creatorDeviceId = payload.newRecord['device_id'] as String?;

            // Only show notification if this insertion wasn't from this device
            if (createdAt != lastLocalInsertTime?.toIso8601String() &&
                creatorDeviceId != _realtimeService!.deviceId) {
              await _realtimeService!.showNotification(habitName);
            }
            await readHabits();
          },
        )..subscribe();
  }

  @override
  void dispose() {
    _habitChannel?.unsubscribe();
    super.dispose();
  }

  // Initialize
  static Future<void> init() async {
    // No additional initialization needed for Supabase
  }

  // Get first launch date
  Future<DateTime?> getFirstLaunchDate() async {
    if (_firstLaunchDate != null) return _firstLaunchDate;

    try {
      final response = await supabase
          .from('app_settings')
          .select('first_launch_date')
          .single();

      _firstLaunchDate = DateTime.parse(response['first_launch_date']);
    } catch (e) {
      // If table is empty or no date exists, set it to today
      _firstLaunchDate = DateTime.now();
      await supabase.from('app_settings').insert({
        'first_launch_date': _firstLaunchDate!.toIso8601String(),
      });
    }

    return _firstLaunchDate;
  }

  // Add new habit
  Future<void> addHabit(String habitName) async {
    try {
      lastLocalInsertTime = DateTime.now();

      // Make sure RealtimeService is initialized
      if (_realtimeService == null) {
        _realtimeService = RealtimeService();
        await _realtimeService!.init();
      }

      final deviceId = _realtimeService!.deviceId;

      logger.d('Adding habit with device ID: $deviceId');

      await supabase.from('habits').insert({
        'name': habitName,
        'completed_days': [],
        'is_archived': false,
        'created_at': lastLocalInsertTime!.toIso8601String(),
        'device_id': deviceId,
      });

      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error adding habit', error: e, stackTrace: stackTrace);
    }
  }

  // Read habits
  Future<void> readHabits() async {
    try {
      // Get ALL habits for heatmap, including archived ones
      final response = await supabase.from('habits').select();

      final habits =
          (response as List).map((habit) => Habit.fromJson(habit)).toList();

      currentHabits.clear();
      currentHabits.addAll(habits);
      notifyListeners();

      // Update the widget
      await updateWidget();
    } catch (e, stackTrace) {
      logger.e('Error fetching habits', error: e, stackTrace: stackTrace);
    }
  }

  // Update habit completion
  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    try {
      final habit = currentHabits.firstWhere((h) => h.id == id);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // Update local state first for immediate UI feedback
      if (isCompleted && !habit.completedDays.contains(todayStart)) {
        habit.completedDays.add(todayStart);
        habit.lastCompletedDate = todayStart;
        habit.isArchived = true;
      } else {
        habit.completedDays.removeWhere(
          (date) =>
              date.year == todayStart.year &&
              date.month == todayStart.month &&
              date.day == todayStart.day,
        );
        habit.lastCompletedDate = null;
        habit.isArchived = false;
      }

      // Update UI immediately
      final index = currentHabits.indexWhere((h) => h.id == id);
      if (index != -1) {
        currentHabits[index] = habit;
        notifyListeners();
      }

      // Update database
      await supabase.from('habits').update({
        'completed_days':
            habit.completedDays.map((e) => e.toIso8601String()).toList(),
        'last_completed_date': habit.lastCompletedDate?.toIso8601String(),
        'is_archived': habit.isArchived,
        'archived_at': habit.isArchived ? todayStart.toIso8601String() : null,
      }).eq('id', id);
    } catch (e, stackTrace) {
      logger.e('Error updating habit completion',
          error: e, stackTrace: stackTrace);
    }
  }

  // Update habit name
  Future<void> updateHabitName(int id, String newName) async {
    try {
      await supabase.from('habits').update({'name': newName}).eq('id', id);

      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error updating habit name', error: e, stackTrace: stackTrace);
    }
  }

  // Delete habit
  Future<void> deleteHabit(int id) async {
    try {
      await supabase.from('habits').delete().eq('id', id);

      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error deleting habit', error: e, stackTrace: stackTrace);
    }
  }

  // Delete completed habits older than one day
  Future<void> deleteCompletedHabits() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      // Get all habits that were completed yesterday or before
      final response = await supabase
          .from('habits')
          .select()
          .not('last_completed_date', 'is', null)
          .lte('last_completed_date', yesterday.toIso8601String())
          .eq('is_archived', false); // Only archive non-archived habits

      final oldHabits =
          (response as List).map((habit) => Habit.fromJson(habit)).toList();

      // Archive these habits
      for (final habit in oldHabits) {
        await supabase.from('habits').update({
          'is_archived': true,
          'archived_at': now.toIso8601String(),
        }).eq('id', habit.id);
      }

      // Refresh the habits list
      await readHabits();
    } catch (e, stackTrace) {
      logger.e('Error archiving completed habits',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> updateWidget() async {
    try {
      final habits = currentHabits;

      // Create a simple dataset for the widget
      final List<String> widgetData = [];
      final now = DateTime.now();

      // For last 35 days
      for (int i = 0; i < 35; i++) {
        final date = now.subtract(Duration(days: 34 - i));
        // Count how many habits were completed on this date
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

      // Send data to the widget
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
