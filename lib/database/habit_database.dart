import 'package:flutter/material.dart';
import 'package:habit_tracker/models/app_settings.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class HabitDatabase extends ChangeNotifier {
  static late Isar isar;

  /*

  S E T U P
  
  */

  // I N I T I A L I Z E - D A T A B A S E
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [HabitSchema, AppSettingsSchema],
      directory: dir.path,
    );
  }

  // Save first date of app startup (for heatmap)
  Future<void> saveFirstLaunchDate() async {
    final currentSettings = await isar.appSettings.where().findFirst();
    if (currentSettings == null) {
      final settings = AppSettings()..firstLaunchDate = DateTime.now();
      await isar.writeTxn(() => isar.appSettings.put(settings));
    }
  }

  // Get first date of app startup (for heatmap)
  Future<DateTime?> getFirstLaunchDate() async {
    final settings = await isar.appSettings.where().findFirst();
    return settings?.firstLaunchDate;
  }

  /*

  C R U D - O P E R A T I O N S

  */

  // List of habits
  final List<Habit> currentHabits = [];

  // C R E A T E - add a new habit
  Future<void> addHabit(String habitName) async {
    // creat a new habit
    final newHabit = Habit()..name = habitName;
    // save to the db
    await isar.writeTxn(() => isar.habits.put(newHabit));
    // re-read from the db
    readHabits();
  }

  // R E A D - read saved habits from database
  Future<void> readHabits() async {
    // fetch all habits from db
    List<Habit> fetchedHabits = await isar.habits.where().findAll();

    // give to current habits
    currentHabits.clear();
    currentHabits.addAll(fetchedHabits);

    // update UI
    notifyListeners();
  }

  // U P D A T E - check habit on and off

  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    // find the habit
    final habit = await isar.habits.get(id);
    // update the status
    if (habit != null) {
      await isar.writeTxn(() async {
        // if habit is completed -> add completion date
        if (isCompleted && !habit.completedDays.contains(DateTime.now())) {
          // add today's date
          final today = DateTime.now();

          // add the current date if it's not already in the list
          habit.completedDays.add(
            DateTime(
              today.year,
              today.month,
              today.day,
            ),
          );
        }

        // * if habit is not completed -> remove completion date
        else {
          // remove the current date if it's marked as not completed
          habit.completedDays.removeWhere(
            (date) =>
                date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day,
          );
        }
        // save the updated habits
        await isar.habits.put(habit);
      });
    }
    // re-read from db
    readHabits();
  }

  // U P D A T E - edit habit name
  Future<void> updateHabitName(int id, String newName) async {
    // find the habit
    final habit = await isar.habits.get(id);

    // update the name
    if (habit != null) {
      await isar.writeTxn(() async {
        habit.name = newName;
        // save the updated habit to db
        await isar.habits.put(habit);
      });
    }
    // re-read from db
    readHabits();
  }

  // D E L E T E - delete habit
  Future<void> deleteHabit(int id) async {
    // delete the habit
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });

    // re-read from db
    readHabits();
  }

  // Delete completed habits older than one day
  Future<void> deleteOldCompletedHabits() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    await isar.writeTxn(() async {
      final oldCompletedHabits = await isar.habits
          .filter()
          .completedDaysElementLessThan(yesterday)
          .findAll();

      for (final habit in oldCompletedHabits) {
        // Remove the habit but keep the completion data for the heatmap
        await isar.habits.delete(habit.id);
      }
    });

    // Re-read habits from the database
    readHabits();
  }
}
