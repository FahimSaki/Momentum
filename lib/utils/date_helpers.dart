/// Date-formatting helpers shared across TaskTile and HomePage.
class DateHelpers {
  DateHelpers._();

  /// Long form: "Due today", "Due tomorrow", "Overdue by 3d", "Due in 5d".
  static String formatDueDate(DateTime dueDate) {
    final diff = dueDate.difference(DateTime.now()).inDays;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Due yesterday';
    if (diff < 0) return 'Overdue by ${-diff}d';
    if (diff <= 7) return 'Due in ${diff}d';
    return 'Due ${dueDate.month}/${dueDate.day}';
  }

  /// Short form used inside task tiles: "Today", "3d overdue", "5d left".
  static String shortDueLabel(DateTime dueDate) {
    final diff = dueDate.difference(DateTime.now()).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff}d overdue';
    if (diff <= 7) return '${diff}d left';
    return '${dueDate.month}/${dueDate.day}';
  }
}
