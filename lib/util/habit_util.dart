// given a habit list of completion days
// is habit completed today

bool isHabitCompletedToday(List<DateTime> completionDays) {
  final today = DateTime.now();
  return completionDays.any(
    (date) =>
        date.day == today.day &&
        date.month == today.month &&
        date.year == today.year,
  );
}
