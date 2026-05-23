import 'package:momentum/models/task.dart';

// ── DateTime helpers ─────────────────────────────────────────────────────

/// Compares two DateTimes by date only (year/month/day).
extension DateOnly on DateTime {
  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

// ── Completion checks ────────────────────────────────────────────────────

/// Returns true if any date in [completionDays] falls on today (local time).
bool isTaskCompletedToday(List<DateTime> completionDays) {
  final today = _localToday();
  return completionDays.any((d) => d.toLocal().isSameDayAs(today));
}

/// Returns true if [task] should be shown in the active list
/// (i.e. NOT completed today).
bool shouldShowTask(Task task) {
  if (task.lastCompletedDate == null) return true;
  return !task.lastCompletedDate!.toLocal().isSameDayAs(_localToday());
}

// ── Heatmap data ─────────────────────────────────────────────────────────

/// Builds the dataset map used by HeatMap, merging current tasks and
/// historical completions. Keys are local-midnight DateTimes; values are
/// completion counts.
Map<DateTime, int> prepareMapDatasets(
  List<Task> tasks, [
  List<DateTime>? historicalCompletions,
]) {
  final Map<DateTime, int> data = {};

  void addDate(DateTime utcDate) {
    final day = _toLocalMidnight(utcDate);
    data.update(day, (c) => c + 1, ifAbsent: () => 1);
  }

  for (final task in tasks) {
    task.completedDays.forEach(addDate);
  }
  historicalCompletions?.forEach(addDate);

  return data;
}

// ── Date range utilities ─────────────────────────────────────────────────

/// Filters [dates] to those within [startDate]...[endDate] (inclusive, local).
List<DateTime> filterDatesByRange(
  List<DateTime> dates,
  DateTime startDate,
  DateTime endDate,
) {
  final start = _toLocalMidnight(startDate);
  final end = _toLocalMidnight(endDate);
  return dates.where((d) {
    final day = _toLocalMidnight(d);
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();
}

/// Counts completions across [tasks] within the given date range.
int countCompletionsInRange(
  List<Task> tasks,
  DateTime startDate,
  DateTime endDate,
) {
  return tasks.fold(
    0,
    (sum, task) =>
        sum + filterDatesByRange(task.completedDays, startDate, endDate).length,
  );
}

// ── Private helpers ──────────────────────────────────────────────────────

DateTime _localToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _toLocalMidnight(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}
