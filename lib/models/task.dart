import 'package:momentum/models/completion_record.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/utils/day_utils.dart';

/// Tracks whether a task's create request has reached the backend yet.
/// Anything loaded from the server is [synced]. Tasks created while
/// offline start as [pendingCreate] until the sync queue replays them
/// successfully; if the server rejects the replay, they move to
/// [syncFailed] instead of being retried forever.
enum TaskSyncStatus { synced, pendingCreate, syncFailed }

TaskSyncStatus _syncStatusFromJson(String? value) {
  switch (value) {
    case 'pendingCreate':
      return TaskSyncStatus.pendingCreate;
    case 'syncFailed':
      return TaskSyncStatus.syncFailed;
    default:
      return TaskSyncStatus.synced;
  }
}

class Task {
  final String id;
  String name;
  String? description;
  List<User> assignedTo;
  User? assignedBy;
  Team? team;
  String priority;
  DateTime? dueDate;
  List<String> tags;

  /// Calendar dates (local midnight) the task was completed on. The server
  /// sends them as day stamps; see day_utils.dart.
  List<DateTime> completedDays;
  List<CompletionRecord> completedBy;
  DateTime? lastCompletedDate;
  bool isArchived;
  DateTime? archivedAt;
  bool isTeamTask;
  String assignmentType;
  DateTime createdAt;
  DateTime updatedAt;
  TaskSyncStatus syncStatus;

  static const String _localIdPrefix = 'local_';

  /// True if [id] is a client-generated placeholder rather than a real
  /// MongoDB id (i.e. the task was created offline and hasn't reached the
  /// backend yet).
  static bool isLocalId(String id) => id.startsWith(_localIdPrefix);

  static String generateLocalId() =>
      '$_localIdPrefix${DateTime.now().microsecondsSinceEpoch}';

  Task({
    required this.id,
    required this.name,
    this.description,
    this.assignedTo = const [],
    this.assignedBy,
    this.team,
    this.priority = 'medium',
    this.dueDate,
    this.tags = const [],
    this.completedDays = const [],
    this.completedBy = const [],
    this.lastCompletedDate,
    this.isArchived = false,
    this.archivedAt,
    this.isTeamTask = false,
    this.assignmentType = 'individual',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = TaskSyncStatus.synced,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      assignedTo:
          (json['assignedTo'] as List<dynamic>?)
              ?.map((u) => User.fromJson(u))
              .toList() ??
          [],
      assignedBy: json['assignedBy'] != null
          ? User.fromJson(json['assignedBy'])
          : null,
      team: json['team'] is Map<String, dynamic>
          ? Team.fromJson(json['team'])
          : null,
      priority: json['priority'] ?? 'medium',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate']).toLocal()
          : null,
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
          [],
      completedDays:
          (json['completedDays'] as List<dynamic>?)
              ?.map((e) => dayStampToDate(DateTime.parse(e)))
              .toList() ??
          [],
      completedBy:
          (json['completedBy'] as List<dynamic>?)
              ?.map((c) => CompletionRecord.fromJson(c))
              .toList() ??
          [],
      lastCompletedDate: json['lastCompletedDate'] != null
          ? dayStampToDate(DateTime.parse(json['lastCompletedDate']))
          : null,
      isArchived: json['isArchived'] ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt']).toLocal()
          : null,
      isTeamTask: json['isTeamTask'] ?? false,
      assignmentType: json['assignmentType'] ?? 'individual',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: _syncStatusFromJson(json['syncStatus'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'description': description,
    'assignedTo': assignedTo.map((u) => u.toJson()).toList(),
    'assignedBy': assignedBy?.toJson(),
    'team': team?.toJson(),
    'priority': priority,
    'dueDate': dueDate?.toIso8601String(),
    'tags': tags,
    // Written back as day stamps so a cached task reads exactly like a fresh one.
    'completedDays': completedDays
        .map((e) => dateToDayStamp(e).toIso8601String())
        .toList(),
    'completedBy': completedBy.map((c) => c.toJson()).toList(),
    'lastCompletedDate': lastCompletedDate == null
        ? null
        : dateToDayStamp(lastCompletedDate!).toIso8601String(),
    'isArchived': isArchived,
    'archivedAt': archivedAt?.toIso8601String(),
    'isTeamTask': isTeamTask,
    'assignmentType': assignmentType,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'syncStatus': syncStatus.name,
  };

  bool isAssignedTo(String userId) => assignedTo.any((u) => u.id == userId);

  bool isCompletedBy(String userId) =>
      completedBy.any((c) => c.user.id == userId);

  /// Completed during the current local day.
  ///
  /// The server archives a task the moment it is completed, so for an archived
  /// task the instant it was archived decides this. That is the same rule
  /// TaskCubit uses to keep archived tasks in its list, so the two cannot
  /// disagree and leave a task that is neither active nor completed. Tasks
  /// with no archive time fall back to their completion days.
  bool isCompletedToday() {
    final today = localToday();
    final archived = archivedAt;
    if (isArchived && archived != null) {
      return isSameDay(archived.toLocal(), today);
    }
    return completedDays.any((d) => isSameDay(d, today));
  }

  bool isCompletedByUserToday(String userId) {
    final today = localToday();
    return completedBy.any((c) {
      if (c.user.id != userId) return false;
      return isSameDay(c.completedAt.toLocal(), today);
    });
  }

  /// True if this task hasn't been confirmed by the backend yet, or the
  /// backend rejected it on retry.
  bool get isPendingSync => syncStatus != TaskSyncStatus.synced;

  /// True only while the task still lives solely on this device.
  bool get isLocalOnly => Task.isLocalId(id);

  bool get isOverdue {
    if (dueDate == null || isArchived) return false;
    return dateOnly(dueDate!.toLocal()).isBefore(localToday()) &&
        !isCompletedToday();
  }

  bool get isDueSoon {
    if (dueDate == null || isArchived) return false;
    final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));
    return dateOnly(dueDate!.toLocal()) == tomorrow && !isCompletedToday();
  }

  String get priorityColor {
    const map = {
      'low': '#4CAF50',
      'medium': '#FF9800',
      'high': '#FF5722',
      'urgent': '#F44336',
    };
    return map[priority] ?? '#FF9800';
  }
}
