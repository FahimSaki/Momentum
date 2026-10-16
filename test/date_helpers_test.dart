import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/utils/date_helpers.dart';
import 'package:momentum/utils/day_utils.dart';

DateTime _daysFromToday(int days) {
  final t = localToday();
  return DateTime(t.year, t.month, t.day + days);
}

void main() {
  group('DateHelpers.formatDueDate', () {
    test('names the days around today', () {
      expect(DateHelpers.formatDueDate(_daysFromToday(0)), 'Due today');
      expect(DateHelpers.formatDueDate(_daysFromToday(1)), 'Due tomorrow');
      expect(DateHelpers.formatDueDate(_daysFromToday(-1)), 'Due yesterday');
    });

    test('counts whole days for overdue and upcoming dates', () {
      expect(DateHelpers.formatDueDate(_daysFromToday(-3)), 'Overdue by 3d');
      expect(DateHelpers.formatDueDate(_daysFromToday(5)), 'Due in 5d');
      expect(DateHelpers.formatDueDate(_daysFromToday(7)), 'Due in 7d');
    });

    test('shows a month/day beyond a week', () {
      final due = _daysFromToday(10);
      expect(DateHelpers.formatDueDate(due), 'Due ${due.month}/${due.day}');
    });

    test('ignores the time of day on the due date', () {
      final t = _daysFromToday(0);
      final lateToday = DateTime(t.year, t.month, t.day, 23, 59);
      expect(DateHelpers.formatDueDate(lateToday), 'Due today');
    });
  });

  group('DateHelpers.shortDueLabel', () {
    test('names the days around today', () {
      expect(DateHelpers.shortDueLabel(_daysFromToday(0)), 'Today');
      expect(DateHelpers.shortDueLabel(_daysFromToday(1)), 'Tomorrow');
      expect(DateHelpers.shortDueLabel(_daysFromToday(-1)), 'Yesterday');
    });

    test('counts whole days for overdue and upcoming dates', () {
      expect(DateHelpers.shortDueLabel(_daysFromToday(-4)), '4d overdue');
      expect(DateHelpers.shortDueLabel(_daysFromToday(6)), '6d left');
    });

    test('shows a month/day beyond a week', () {
      final due = _daysFromToday(12);
      expect(DateHelpers.shortDueLabel(due), '${due.month}/${due.day}');
    });
  });
}
