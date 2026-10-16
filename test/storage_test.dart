import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/database/local_cache_service.dart';
import 'package:momentum/database/sync_queue_service.dart';
import 'package:momentum/models/notification_settings.dart';
import 'package:momentum/models/pending_task_create.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/models/team_settings.dart';
import 'package:momentum/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingTaskCreate _pending(String localId, {String name = 'Offline task'}) =>
    PendingTaskCreate(
      localId: localId,
      name: name,
      priority: 'high',
      assignmentType: 'individual',
      queuedAt: DateTime(2026, 10, 3, 9, 30),
    );

Task _task(String id, {String name = 'Task'}) => Task(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingTaskCreate', () {
    test('toJson then fromJson keeps every field', () {
      final original = PendingTaskCreate(
        localId: 'local_1',
        name: 'Write tests',
        description: 'Cover storage',
        assignedTo: const ['u1', 'u2'],
        teamId: null,
        priority: 'urgent',
        dueDate: DateTime(2026, 10, 5),
        tags: const ['testing'],
        assignmentType: 'multiple',
        queuedAt: DateTime(2026, 10, 3, 9, 30),
      );

      final copy = PendingTaskCreate.fromJson(original.toJson());

      expect(copy.localId, 'local_1');
      expect(copy.name, 'Write tests');
      expect(copy.description, 'Cover storage');
      expect(copy.assignedTo, ['u1', 'u2']);
      expect(copy.teamId, isNull);
      expect(copy.priority, 'urgent');
      expect(copy.dueDate!.isAtSameMomentAs(DateTime(2026, 10, 5)), isTrue);
      expect(copy.tags, ['testing']);
      expect(copy.assignmentType, 'multiple');
      expect(
        copy.queuedAt.isAtSameMomentAs(DateTime(2026, 10, 3, 9, 30)),
        isTrue,
      );
    });

    test('fromJson applies defaults for missing optional fields', () {
      final p = PendingTaskCreate.fromJson({'localId': 'local_1', 'name': 'N'});

      expect(p.priority, 'medium');
      expect(p.assignmentType, 'individual');
      expect(p.dueDate, isNull);
      expect(p.tags, isNull);
      expect(p.description, isNull);
    });
  });

  group('SyncQueueService', () {
    test('starts empty', () async {
      expect(await SyncQueueService().getPending(), isEmpty);
    });

    test('enqueue keeps operations in order', () async {
      final queue = SyncQueueService();
      await queue.enqueue(_pending('local_1', name: 'First'));
      await queue.enqueue(_pending('local_2', name: 'Second'));

      final pending = await queue.getPending();

      expect(pending.map((p) => p.localId), ['local_1', 'local_2']);
      expect(pending.map((p) => p.name), ['First', 'Second']);
    });

    test('the queue survives a new service instance', () async {
      await SyncQueueService().enqueue(_pending('local_1'));

      final pending = await SyncQueueService().getPending();

      expect(pending.single.localId, 'local_1');
    });

    test('remove drops only the matching operation', () async {
      final queue = SyncQueueService();
      await queue.enqueue(_pending('local_1'));
      await queue.enqueue(_pending('local_2'));

      await queue.remove('local_1');

      expect((await queue.getPending()).map((p) => p.localId), ['local_2']);
    });

    test('removing an unknown id changes nothing', () async {
      final queue = SyncQueueService();
      await queue.enqueue(_pending('local_1'));

      await queue.remove('local_999');

      expect((await queue.getPending()).length, 1);
    });

    test('clear empties the queue', () async {
      final queue = SyncQueueService();
      await queue.enqueue(_pending('local_1'));

      await queue.clear();

      expect(await queue.getPending(), isEmpty);
    });

    test('unreadable stored data reads as an empty queue', () async {
      SharedPreferences.setMockInitialValues({
        'sync_queue_pending_task_creates': 'this is not json',
      });

      expect(await SyncQueueService().getPending(), isEmpty);
    });
  });

  group('LocalCacheService', () {
    test('tasks are cached separately for personal and each team', () async {
      final cache = LocalCacheService();
      await cache.saveTasks(null, [_task('personal-1', name: 'Mine')]);
      await cache.saveTasks('team-a', [_task('a-1'), _task('a-2')]);

      final personal = await cache.loadTasks(null);
      final teamA = await cache.loadTasks('team-a');

      expect(personal.single.name, 'Mine');
      expect(teamA.map((t) => t.id), ['a-1', 'a-2']);
      expect(await cache.loadTasks('team-b'), isEmpty);
    });

    test('saving again replaces the previous cache for that scope', () async {
      final cache = LocalCacheService();
      await cache.saveTasks(null, [_task('old')]);
      await cache.saveTasks(null, [_task('new')]);

      expect((await cache.loadTasks(null)).single.id, 'new');
    });

    test('dashboard stats round trip and are null when never saved', () async {
      final cache = LocalCacheService();
      expect(await cache.loadDashboardStats(null), isNull);

      await cache.saveDashboardStats('team-a', {
        'totalTasks': 4,
        'completedToday': 2,
        'overdueTasks': 1,
        'upcomingTasks': 3,
      });

      final stats = await cache.loadDashboardStats('team-a');
      expect(stats, {
        'totalTasks': 4,
        'completedToday': 2,
        'overdueTasks': 1,
        'upcomingTasks': 3,
      });
      expect(await cache.loadDashboardStats(null), isNull);
    });

    test('historical completions round trip as local dates', () async {
      final cache = LocalCacheService();
      await cache.saveHistoricalCompletions(null, [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 3),
      ]);

      final loaded = await cache.loadHistoricalCompletions(null);

      expect(loaded, [DateTime(2026, 10, 1), DateTime(2026, 10, 3)]);
      expect(await cache.loadHistoricalCompletions('team-a'), isEmpty);
    });

    test('teams round trip with their owner and members', () async {
      User user(String id) => User.placeholder(id: id, name: 'User $id');
      final team = Team(
        id: 't1',
        name: 'Team One',
        description: 'The first team',
        owner: user('owner1'),
        members: [
          TeamMember(
            user: user('owner1'),
            role: 'owner',
            joinedAt: DateTime(2026, 1, 1),
          ),
          TeamMember(
            user: user('member1'),
            role: 'member',
            joinedAt: DateTime(2026, 1, 2),
          ),
        ],
        settings: TeamSettings(
          allowMemberInvite: true,
          notificationSettings: NotificationSettings(taskCompleted: false),
        ),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final cache = LocalCacheService();

      await cache.saveTeams([team]);
      final loaded = (await cache.loadTeams()).single;

      expect(loaded.id, 't1');
      expect(loaded.name, 'Team One');
      expect(loaded.owner.id, 'owner1');
      expect(loaded.members.map((m) => m.role), ['owner', 'member']);
      expect(loaded.settings.allowMemberInvite, isTrue);
      expect(loaded.settings.notificationSettings.taskCompleted, isFalse);
      expect(loaded.settings.notificationSettings.taskAssigned, isTrue);
    });

    test('clearAll removes every cache key and nothing else', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});
      final cache = LocalCacheService();
      await cache.saveTasks(null, [_task('1')]);
      await cache.saveTasks('team-a', [_task('2')]);
      await cache.saveDashboardStats(null, {'totalTasks': 1});
      await cache.saveHistoricalCompletions(null, [DateTime(2026, 10, 1)]);
      await cache.saveTeams([]);

      await cache.clearAll();

      expect(await cache.loadTasks(null), isEmpty);
      expect(await cache.loadTasks('team-a'), isEmpty);
      expect(await cache.loadDashboardStats(null), isNull);
      expect(await cache.loadHistoricalCompletions(null), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), isTrue);
    });
  });
}
