import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';

class TaskState {
  final List<Task> currentTasks;
  final List<DateTime> historicalCompletions;
  final Map<String, int> dashboardStats;
  final Team? selectedTeam;
  final bool isOffline;
  final bool isInitialized;

  static const _emptyStats = {
    'totalTasks': 0,
    'completedToday': 0,
    'overdueTasks': 0,
    'upcomingTasks': 0,
  };

  const TaskState({
    this.currentTasks = const [],
    this.historicalCompletions = const [],
    this.dashboardStats = _emptyStats,
    this.selectedTeam,
    this.isOffline = false,
    this.isInitialized = false,
  });

  List<Task> get personalTasks =>
      currentTasks.where((t) => !t.isTeamTask).toList();
  List<Task> get teamTasks => currentTasks.where((t) => t.isTeamTask).toList();
  List<Task> get activeTasks => currentTasks
      .where((task) => !task.isCompletedToday() && !task.isArchived)
      .toList();
  List<Task> get completedTasks =>
      currentTasks.where((task) => task.isCompletedToday()).toList();

  /// Never changes selectedTeam via copyWith — always carries the
  /// current value forward. TaskCubit._onTeamChanged constructs a
  /// TaskState directly instead, to avoid the usual
  /// copyWith-can't-null-a-field problem.
  TaskState copyWith({
    List<Task>? currentTasks,
    List<DateTime>? historicalCompletions,
    Map<String, int>? dashboardStats,
    bool? isOffline,
    bool? isInitialized,
  }) {
    return TaskState(
      currentTasks: currentTasks ?? this.currentTasks,
      historicalCompletions:
          historicalCompletions ?? this.historicalCompletions,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      selectedTeam: selectedTeam,
      isOffline: isOffline ?? this.isOffline,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}
