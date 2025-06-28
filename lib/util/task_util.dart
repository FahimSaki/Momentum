import 'package:habit_tracker/models/task.dart';

Map<DateTime, int> prepareMapDatasets(List<Task> tasks) {
  final Map<DateTime, int> map = {};
  for (var task in tasks) {
    final date =
        DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    map[date] = (map[date] ?? 0) + 1;
  }
  return map;
}
