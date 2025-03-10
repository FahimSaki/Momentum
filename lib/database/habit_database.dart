import 'package:flutter/material.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class HabitDatabase extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  final Logger logger = Logger();
  final List<Habit> currentHabits = [];
  DateTime? _firstLaunchDate;

  // Initialize
  static Future<void> init() async {
    // No initialization needed for Supabase
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
      await supabase.from('habits').insert({
        'name': habitName,
        'completed_days': [],
        'is_archived': false,
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

      if (isCompleted && !habit.completedDays.contains(today)) {
        // Set completion date to start of today
        habit.completedDays.add(todayStart);
        habit.lastCompletedDate = todayStart;

        // Update in Supabase including archived status
        await supabase.from('habits').update({
          'completed_days':
              habit.completedDays.map((e) => e.toIso8601String()).toList(),
          'last_completed_date': habit.lastCompletedDate?.toIso8601String(),
          'is_archived': true,
          'archived_at': todayStart.toIso8601String(),
        }).eq('id', id);
      } else {
        habit.completedDays.removeWhere(
          (date) =>
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day,
        );
        habit.lastCompletedDate = null;

        // Reset archived status when uncompleting
        await supabase.from('habits').update({
          'completed_days':
              habit.completedDays.map((e) => e.toIso8601String()).toList(),
          'last_completed_date': null,
          'is_archived': false,
          'archived_at': null,
        }).eq('id', id);
      }

      // Refresh habits list
      await readHabits();
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
}
