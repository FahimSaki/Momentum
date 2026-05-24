import 'package:momentum/models/task.dart';

// ── Completion helpers ───────────────────────────────────────────────────

/// Returns true if any date in [completionDays] falls on today (local time).
bool isTaskCompletedToday(List<DateTime> completionDays) {
  final today = _localToday();
  return completionDays.any((d) => _toLocalDay(d) == today);
}

/// Returns true if [task] should appear in the active list
/// (i.e. not completed today).
bool shouldShowTask(Task task) {
  if (task.lastCompletedDate == null) return true;
  return _toLocalDay(task.lastCompletedDate!) != _localToday();
}

// ── Heatmap data ─────────────────────────────────────────────────────────

/// Builds the dataset map for HeatMap, merging current tasks and
/// optional historical completions. Keys are local-midnight DateTimes;
/// values are completion counts.
Map<DateTime, int> prepareMapDatasets(
  List<Task> tasks, [
  List<DateTime>? historicalCompletions,
]) {
  final data = <DateTime, int>{};

  void add(DateTime d) {
    final day = _toLocalDay(d);
    data[day] = (data[day] ?? 0) + 1;
  }

  for (final task in tasks) {
    task.completedDays.forEach(add);
  }
  historicalCompletions?.forEach(add);

  return data;
}

// ── Date range utilities ─────────────────────────────────────────────────

/// Filters [dates] to those within [startDate]...[endDate] (inclusive).
List<DateTime> filterDatesByRange(
  List<DateTime> dates,
  DateTime startDate,
  DateTime endDate,
) {
  final start = _toLocalDay(startDate);
  final end = _toLocalDay(endDate);
  return dates.where((d) {
    final day = _toLocalDay(d);
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();
}

/// Counts completions across [tasks] within the given date range.
int countCompletionsInRange(
  List<Task> tasks,
  DateTime startDate,
  DateTime endDate,
) => tasks.fold(
  0,
  (sum, t) =>
      sum + filterDatesByRange(t.completedDays, startDate, endDate).length,
);

// ── Private helpers ──────────────────────────────────────────────────────

DateTime _localToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _toLocalDay(DateTime dt) {
  final l = dt.toLocal();
  return DateTime(l.year, l.month, l.day);
}
