import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/utils/day_utils.dart';

// Run under a few zones to cover both sides of UTC:
//   TZ=America/New_York flutter test test/day_utils_test.dart
//   TZ=Asia/Dhaka       flutter test test/day_utils_test.dart
//   TZ=Pacific/Kiritimati flutter test test/day_utils_test.dart

Map<String, dynamic> _json(List<String> days) => {
  '_id': '1',
  'name': 'T',
  'completedDays': days,
  'createdAt': '2026-10-03T00:00:00.000Z',
  'updatedAt': '2026-10-03T00:00:00.000Z',
};

Task _task({
  List<DateTime> completedDays = const [],
  bool isArchived = false,
  DateTime? archivedAt,
  DateTime? archiveExpiresAt,
}) => Task(
  id: '1',
  name: 'T',
  completedDays: List.of(completedDays),
  isArchived: isArchived,
  archivedAt: archivedAt,
  archiveExpiresAt: archiveExpiresAt,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final now = DateTime.now();
  final yesterdayNoon = DateTime(now.year, now.month, now.day - 1, 12);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  group('day stamps', () {
    test('a stamp names its calendar date whatever the device zone is', () {
      expect(
        dayStampToDate(DateTime.parse('2026-10-03T00:00:00.000Z')),
        DateTime(2026, 10, 3),
      );
    });

    test('dateToDayStamp writes UTC midnight', () {
      expect(dateToDayStamp(DateTime(2026, 10, 3)), DateTime.utc(2026, 10, 3));
    });

    test('date to stamp to date round trips', () {
      final date = DateTime(2026, 12, 31);
      expect(dayStampToDate(dateToDayStamp(date)), date);
    });
  });

  group('Task day handling', () {
    test('completedDays are read as calendar dates, not instants', () {
      final task = Task.fromJson(_json(['2026-10-03T00:00:00.000Z']));
      expect(task.completedDays, [DateTime(2026, 10, 3)]);
    });

    test('toJson writes stamps that read back as the same dates', () {
      final task = Task.fromJson(_json(['2026-10-03T00:00:00.000Z']));
      final json = task.toJson();
      expect(json['completedDays'], ['2026-10-03T00:00:00.000Z']);
      expect(Task.fromJson(json).completedDays, [DateTime(2026, 10, 3)]);
    });

    test('archived earlier today counts as completed today', () {
      final task = _task(isArchived: true, archivedAt: DateTime.now());
      expect(task.isCompletedToday(), isTrue);
    });

    test('archived yesterday does not, even with a stamp for today', () {
      final task = _task(
        isArchived: true,
        archivedAt: yesterdayNoon,
        completedDays: [localToday()],
      );
      expect(task.isCompletedToday(), isFalse);
    });

    test('with no archive time it falls back to completion days', () {
      expect(_task(completedDays: [localToday()]).isCompletedToday(), isTrue);
      expect(_task(completedDays: [yesterday]).isCompletedToday(), isFalse);
    });
  });

  group('archive window and due dates', () {
    test('an archived task counts as completed until its expiry passes', () {
      final live = _task(
        isArchived: true,
        archivedAt: yesterdayNoon,
        archiveExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final expired = _task(
        isArchived: true,
        archivedAt: DateTime.now(),
        archiveExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(live.isCompletedToday(), isTrue);
      expect(expired.isCompletedToday(), isFalse);
    });

    test('archiveExpiresAt survives a cache round trip', () {
      final expires = DateTime.now().add(const Duration(hours: 3));
      final json = _json([])
        ..['archiveExpiresAt'] = expires.toUtc().toIso8601String();
      final task = Task.fromJson(json);
      expect(task.archiveExpiresAt!.isAtSameMomentAs(expires), isTrue);
      expect(
        Task.fromJson(
          task.toJson(),
        ).archiveExpiresAt!.isAtSameMomentAs(expires),
        isTrue,
      );
    });

    test('due dates are read as calendar dates and written as stamps', () {
      final json = _json([])..['dueDate'] = '2026-10-05T00:00:00.000Z';
      final task = Task.fromJson(json);
      expect(task.dueDate, DateTime(2026, 10, 5));
      expect(task.toJson()['dueDate'], '2026-10-05T00:00:00.000Z');
    });

    test('daysBetween counts calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 3, 23), DateTime(2026, 10, 4)), 1);
      expect(daysBetween(DateTime(2026, 10, 4), DateTime(2026, 10, 3)), -1);
      expect(daysBetween(DateTime(2026, 10, 3), DateTime(2026, 10, 3, 23)), 0);
    });
  });
}
