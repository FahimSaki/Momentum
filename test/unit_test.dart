import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/utils/day_utils.dart';
import 'package:momentum/utils/task_util.dart';

Task _task({
  String id = 'test-id',
  String name = 'Test Task',
  List<DateTime> completedDays = const [],
  DateTime? lastCompletedDate,
  DateTime? dueDate,
  bool isArchived = false,
  TaskSyncStatus syncStatus = TaskSyncStatus.synced,
}) => Task(
  id: id,
  name: name,
  completedDays: completedDays,
  lastCompletedDate: lastCompletedDate,
  dueDate: dueDate,
  isArchived: isArchived,
  syncStatus: syncStatus,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

DateTime _daysFromToday(int days) {
  final t = localToday();
  return DateTime(t.year, t.month, t.day + days);
}

void main() {
  group('Task model', () {
    test('fromJson reads the fields the backend sends', () {
      final task = Task.fromJson({
        '_id': 'test-id',
        'name': 'Test Task',
        'completedDays': ['2024-01-01T00:00:00.000Z'],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      expect(task.id, 'test-id');
      expect(task.name, 'Test Task');
      expect(task.completedDays, [DateTime(2024, 1, 1)]);
      expect(task.isArchived, isFalse);
    });

    test('fromJson tolerates null optional fields', () {
      final task = Task.fromJson({
        '_id': 'test-id',
        'name': 'Test Task',
        'completedDays': null,
        'lastCompletedDate': null,
        'isArchived': null,
        'archivedAt': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      expect(task.completedDays, isEmpty);
      expect(task.lastCompletedDate, isNull);
      expect(task.isArchived, isFalse);
      expect(task.archivedAt, isNull);
      expect(task.priority, 'medium');
      expect(task.assignmentType, 'individual');
    });

    test('toJson uses the backend field names', () {
      final json = _task(completedDays: [DateTime(2024, 1, 1)]).toJson();

      expect(json['_id'], 'test-id');
      expect(json['name'], 'Test Task');
      expect(json['isArchived'], isFalse);
      expect(json['completedDays'], ['2024-01-01T00:00:00.000Z']);
    });

    test('toJson then fromJson keeps every field the cache relies on', () {
      final original = Task(
        id: 'test-id',
        name: 'Test Task',
        description: 'Cover the model',
        priority: 'high',
        tags: const ['testing'],
        completedDays: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
        lastCompletedDate: DateTime(2024, 1, 2),
        isArchived: true,
        archivedAt: DateTime(2024, 1, 3, 10),
        isTeamTask: true,
        assignmentType: 'team',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        syncStatus: TaskSyncStatus.syncFailed,
      );

      final copy = Task.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.description, original.description);
      expect(copy.priority, original.priority);
      expect(copy.tags, original.tags);
      expect(copy.completedDays, original.completedDays);
      expect(copy.lastCompletedDate, original.lastCompletedDate);
      expect(copy.isArchived, isTrue);
      expect(copy.isTeamTask, isTrue);
      expect(copy.assignmentType, 'team');
      expect(copy.syncStatus, TaskSyncStatus.syncFailed);
    });
  });

  group('Offline sync status', () {
    test('local ids are recognised and server ids are not', () {
      expect(Task.isLocalId('local_1767225600000000'), isTrue);
      expect(Task.isLocalId('665f1c2a9b1e4c0012ab34cd'), isFalse);
      expect(Task.isLocalId(Task.generateLocalId()), isTrue);
    });

    test('a synced task is not pending and not local', () {
      final task = _task(id: '665f1c2a9b1e4c0012ab34cd');
      expect(task.isPendingSync, isFalse);
      expect(task.isLocalOnly, isFalse);
    });

    test('a queued or failed task counts as pending sync', () {
      expect(
        _task(syncStatus: TaskSyncStatus.pendingCreate).isPendingSync,
        isTrue,
      );
      expect(
        _task(syncStatus: TaskSyncStatus.syncFailed).isPendingSync,
        isTrue,
      );
    });

    test('only a task that still has a local id is local-only', () {
      expect(_task(id: 'local_1').isLocalOnly, isTrue);
    });

    test('an unknown or missing syncStatus reads as synced', () {
      const base = {
        '_id': '1',
        'name': 'T',
        'createdAt': '2026-10-03T00:00:00.000Z',
        'updatedAt': '2026-10-03T00:00:00.000Z',
      };
      expect(Task.fromJson(base).syncStatus, TaskSyncStatus.synced);
      expect(
        Task.fromJson({...base, 'syncStatus': 'something-new'}).syncStatus,
        TaskSyncStatus.synced,
      );
    });
  });

  group('Overdue', () {
    test('a task due before today is overdue', () {
      expect(_task(dueDate: _daysFromToday(-1)).isOverdue, isTrue);
    });

    test('a task due today or later is not overdue', () {
      expect(_task(dueDate: _daysFromToday(0)).isOverdue, isFalse);
      expect(_task(dueDate: _daysFromToday(3)).isOverdue, isFalse);
    });

    test('a task with no due date is never overdue', () {
      expect(_task().isOverdue, isFalse);
    });

    test('completing or archiving an overdue task clears the flag', () {
      final yesterday = _daysFromToday(-1);
      expect(
        _task(dueDate: yesterday, completedDays: [localToday()]).isOverdue,
        isFalse,
      );
      expect(_task(dueDate: yesterday, isArchived: true).isOverdue, isFalse);
    });
  });

  group('Heatmap data', () {
    test('prepareMapDatasets counts completions per local day', () {
      final tasks = [
        _task(
          id: '1',
          completedDays: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
        ),
        _task(id: '2', completedDays: [DateTime(2024, 1, 1)]),
      ];

      final result = prepareMapDatasets(tasks);

      expect(result.length, 2);
      expect(result[DateTime(2024, 1, 1)], 2);
      expect(result[DateTime(2024, 1, 2)], 1);
    });

    test('prepareMapDatasets adds historical completions on top', () {
      final result = prepareMapDatasets(
        [
          _task(completedDays: [DateTime(2024, 1, 1)]),
        ],
        [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
      );

      expect(result[DateTime(2024, 1, 1)], 2);
      expect(result[DateTime(2024, 1, 2)], 1);
    });

    test('prepareMapDatasets of nothing is empty', () {
      expect(prepareMapDatasets([]), isEmpty);
    });

    test('filterDatesByRange is inclusive at both ends and ignores time', () {
      final dates = [
        DateTime(2024, 1, 1, 23, 59),
        DateTime(2024, 1, 5, 8),
        DateTime(2024, 1, 6),
        DateTime(2023, 12, 31),
      ];

      final result = filterDatesByRange(
        dates,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
      );

      expect(result, [DateTime(2024, 1, 1, 23, 59), DateTime(2024, 1, 5, 8)]);
    });

    test('countCompletionsInRange sums across tasks', () {
      final tasks = [
        _task(
          id: '1',
          completedDays: [
            DateTime(2024, 1, 1),
            DateTime(2024, 1, 2),
            DateTime(2024, 1, 10),
          ],
        ),
        _task(id: '2', completedDays: [DateTime(2024, 1, 2)]),
      ];

      expect(
        countCompletionsInRange(
          tasks,
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 5),
        ),
        3,
      );
    });
  });

  group('Completed today', () {
    test('isTaskCompletedToday matches today at any time of day', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      expect(isTaskCompletedToday([now]), isTrue);
      expect(
        isTaskCompletedToday([DateTime(now.year, now.month, now.day, 14, 30)]),
        isTrue,
      );
      expect(isTaskCompletedToday([yesterday, now]), isTrue);
      expect(isTaskCompletedToday([yesterday]), isFalse);
      expect(isTaskCompletedToday([]), isFalse);
    });

    test('shouldShowTask hides a task last completed today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      expect(shouldShowTask(_task()), isTrue);
      expect(shouldShowTask(_task(lastCompletedDate: yesterday)), isTrue);
      expect(shouldShowTask(_task(lastCompletedDate: today)), isFalse);
      expect(shouldShowTask(_task(lastCompletedDate: now)), isFalse);
    });
  });
}
