import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/util/task_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DateTime extension to compare only year/month/day
extension DateOnlyCompare on DateTime {
  bool isAtSameMoment(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

void main() {
  // Setup shared preferences mock for all tests
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Task Model Tests', () {
    test('Task creation from JSON works correctly', () {
      final json = {
        '_id': 'test-id',
        'name': 'Test Task',
        'completedDays': ['2024-01-01T00:00:00.000Z'],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final task = Task.fromJson(json);

      expect(task.id, equals('test-id'));
      expect(task.name, equals('Test Task'));
      expect(task.completedDays.length, equals(1));
      expect(task.isArchived, equals(false));
    });

    test('Task toJson works correctly', () {
      final task = Task(
        id: 'test-id',
        name: 'Test Task',
        completedDays: [DateTime(2024, 1, 1)],
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = task.toJson();

      expect(json['_id'], equals('test-id'));
      expect(json['name'], equals('Test Task'));
      expect(json['isArchived'], equals(false));
    });

    test('Task with empty completedDays', () {
      final task = Task(
        id: 'test-id',
        name: 'Empty Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.completedDays, isEmpty);
      expect(task.isArchived, isFalse);
      expect(task.lastCompletedDate, isNull);
    });

    test('Task with multiple completion days', () {
      final dates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
        DateTime(2024, 1, 3),
      ];

      final task = Task(
        id: 'test-id',
        name: 'Multi Day Task',
        completedDays: dates,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.completedDays.length, equals(3));
      expect(task.completedDays.contains(dates[0]), isTrue);
      expect(task.completedDays.contains(dates[1]), isTrue);
      expect(task.completedDays.contains(dates[2]), isTrue);
    });
  });

  group('Task Utility Tests', () {
    test('prepareMapDatasets creates correct heatmap data', () {
      final tasks = [
        Task(
          id: '1',
          name: 'Task 1',
          completedDays: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Task(
          id: '2',
          name: 'Task 2',
          completedDays: [DateTime(2024, 1, 1)],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = prepareMapDatasets(tasks);

      expect(result.length, equals(2));
      expect(result[DateTime(2024, 1, 1)], equals(2));
      expect(result[DateTime(2024, 1, 2)], equals(1));
    });

    test('prepareMapDatasets with historical data', () {
      final tasks = [
        Task(
          id: '1',
          name: 'Task 1',
          completedDays: [DateTime(2024, 1, 1)],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final historicalCompletions = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
      ];

      final result = prepareMapDatasets(tasks, historicalCompletions);

      expect(result.length, equals(2));
      expect(result[DateTime(2024, 1, 1)], equals(2));
      expect(result[DateTime(2024, 1, 2)], equals(1));
    });

    test('isTaskCompletedToday works correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final todayCompletions = [DateTime.now()];
      expect(isTaskCompletedToday(todayCompletions), isTrue);

      final yesterdayCompletions = [yesterday];
      expect(isTaskCompletedToday(yesterdayCompletions), isFalse);

      expect(isTaskCompletedToday([]), isFalse);

      final multipleCompletions = [yesterday, DateTime.now()];
      expect(isTaskCompletedToday(multipleCompletions), isTrue);

      final todayWithTime = DateTime(now.year, now.month, now.day, 14, 30);
      expect(isTaskCompletedToday([todayWithTime]), isTrue);

      expect(isTaskCompletedToday([today]), isTrue);
    });

    test('shouldShowTask works correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final newTask = Task(
        id: '1',
        name: 'New Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shouldShowTask(newTask), isTrue);

      final yesterdayTask = Task(
        id: '2',
        name: 'Yesterday Task',
        lastCompletedDate: yesterday,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shouldShowTask(yesterdayTask), isTrue);

      final todayTask = Task(
        id: '3',
        name: 'Today Task',
        lastCompletedDate: today,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shouldShowTask(todayTask), isFalse);

      final todayWithTime = Task(
        id: '4',
        name: 'Today with Time Task',
        lastCompletedDate: DateTime(now.year, now.month, now.day, 14, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shouldShowTask(todayWithTime), isFalse);

      final nowTask = Task(
        id: '5',
        name: 'Now Task',
        lastCompletedDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shouldShowTask(nowTask), isFalse);
    });
  });

  group('Date Utility Tests', () {
    test('DateTime comparison extension works', () {
      final date1 = DateTime(2024, 1, 1, 10, 30);
      final date2 = DateTime(2024, 1, 1, 15, 45);
      final date3 = DateTime(2024, 1, 2, 10, 30);

      expect(date1.isAtSameMoment(date2), isTrue);
      expect(date1.isAtSameMoment(date3), isFalse);
    });

    test('Date normalization', () {
      final dateWithTime = DateTime(2024, 1, 1, 14, 30, 45);
      final normalizedDate = DateTime(
        dateWithTime.year,
        dateWithTime.month,
        dateWithTime.day,
      );

      expect(normalizedDate.hour, equals(0));
      expect(normalizedDate.minute, equals(0));
      expect(normalizedDate.second, equals(0));
    });
  });

  group('Edge Case Tests', () {
    test('Empty task list handling', () {
      final result = prepareMapDatasets([]);
      expect(result, isEmpty);
    });

    test('Task with null values', () {
      final json = {
        '_id': 'test-id',
        'name': 'Test Task',
        'completedDays': null,
        'lastCompletedDate': null,
        'isArchived': null,
        'archivedAt': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final task = Task.fromJson(json);

      expect(task.id, equals('test-id'));
      expect(task.name, equals('Test Task'));
      expect(task.completedDays, isEmpty);
      expect(task.lastCompletedDate, isNull);
      expect(task.isArchived, isFalse);
      expect(task.archivedAt, isNull);
    });

    test('Task JSON serialization roundtrip', () {
      final originalTask = Task(
        id: 'test-id',
        name: 'Test Task',
        completedDays: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
        lastCompletedDate: DateTime(2024, 1, 2),
        isArchived: true,
        archivedAt: DateTime(2024, 1, 3),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = originalTask.toJson();
      final recreatedTask = Task.fromJson(json);

      expect(recreatedTask.id, equals(originalTask.id));
      expect(recreatedTask.name, equals(originalTask.name));
      expect(
        recreatedTask.completedDays.length,
        equals(originalTask.completedDays.length),
      );
      expect(recreatedTask.isArchived, equals(originalTask.isArchived));
    });
  });

  group('Constants and Configuration', () {
    test('Basic constants are accessible', () {
      expect(true, isTrue);
    });
  });
}
