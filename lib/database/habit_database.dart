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
      final response = await supabase
          .from('habits')
          .select()
          .eq('is_archived', false); // Only get non-archived habits

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

      if (isCompleted && !habit.completedDays.contains(today)) {
        habit.completedDays.add(DateTime(today.year, today.month, today.day));
        habit.lastCompletedDate = today;
      } else {
        habit.completedDays.removeWhere(
          (date) =>
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day,
        );
        habit.lastCompletedDate = null;
      }

      await supabase.from('habits').update(habit.toJson()).eq('id', id);

      notifyListeners();
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
