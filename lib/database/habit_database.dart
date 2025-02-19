import 'package:flutter/material.dart';
import 'package:habit_tracker/models/app_settings.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class HabitDatabase extends ChangeNotifier {
  static late Isar isar;
  final supabase = Supabase.instance.client;
  final Logger logger = Logger();

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [HabitSchema, AppSettingsSchema],
      directory: dir.path,
    );
  }

  Future<void> saveFirstLaunchDate() async {
    final currentSettings = await isar.appSettings.where().findFirst();
    if (currentSettings == null) {
      final settings = AppSettings()..firstLaunchDate = DateTime.now();
      await isar.writeTxn(() => isar.appSettings.put(settings));
    }
  }

  Future<DateTime?> getFirstLaunchDate() async {
    final settings = await isar.appSettings.where().findFirst();
    return settings?.firstLaunchDate;
  }

  final List<Habit> currentHabits = [];

  Future<void> addHabit(String habitName) async {
    final newHabit = Habit()..name = habitName;
    await isar.writeTxn(() => isar.habits.put(newHabit));
    await supabase.from('habits').insert({
      'id': newHabit.id,
      'name': newHabit.name,
      'completed_days':
          newHabit.completedDays.map((e) => e.toIso8601String()).toList(),
    });
    readHabits();
  }

  Future<void> readHabits() async {
    List<Habit> fetchedHabits = await isar.habits.where().findAll();
    try {
      final List supabaseHabits = await supabase.from('habits').select();
      for (var habit in supabaseHabits) {
        if (!fetchedHabits.any((h) => h.id == habit['id'])) {
          fetchedHabits.add(Habit()
            ..id = habit['id']
            ..name = habit['name']
            ..completedDays = (habit['completed_days'] as List)
                .map((e) => DateTime.parse(e))
                .toList());
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching habits from Supabase',
          error: e, stackTrace: stackTrace);
    }

    currentHabits.clear();
    currentHabits.addAll(fetchedHabits);
    notifyListeners();
  }

  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        if (isCompleted && !habit.completedDays.contains(DateTime.now())) {
          final today = DateTime.now();
          habit.completedDays.add(
            DateTime(today.year, today.month, today.day),
          );
        } else {
          habit.completedDays.removeWhere(
            (date) =>
                date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day,
          );
        }
        await isar.habits.put(habit);
      });
      await supabase.from('habits').update({
        'completed_days':
            habit.completedDays.map((e) => e.toIso8601String()).toList(),
      }).eq('id', id);
    }
    readHabits();
  }

  Future<void> updateHabitName(int id, String newName) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        habit.name = newName;
        await isar.habits.put(habit);
      });
      await supabase.from('habits').update({
        'name': newName,
      }).eq('id', id);
    }
    readHabits();
  }

  Future<void> deleteHabit(int id) async {
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });
    await supabase.from('habits').delete().eq('id', id);
    readHabits();
  }

  Future<void> deleteOldCompletedHabits() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    await isar.writeTxn(() async {
      final oldCompletedHabits = await isar.habits
          .filter()
          .completedDaysElementLessThan(yesterday)
          .findAll();
      for (final habit in oldCompletedHabits) {
        await isar.habits.delete(habit.id);
      }
    });
    await supabase
        .from('habits')
        .delete()
        .lt('completed_days', yesterday.toIso8601String());
    readHabits();
  }
}
