import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/blocs/notification_state.dart';
import 'package:momentum/blocs/session_cubit.dart';
import 'package:momentum/blocs/session_state.dart';
import 'package:momentum/blocs/task_state.dart';
import 'package:momentum/blocs/team_cubit.dart';
import 'package:momentum/blocs/team_state.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/utils/day_utils.dart';

Task _task(
  String id, {
  List<DateTime> completedDays = const [],
  bool isArchived = false,
  DateTime? archiveExpiresAt,
  bool isTeamTask = false,
}) => Task(
  id: id,
  name: 'Task $id',
  completedDays: completedDays,
  isArchived: isArchived,
  archiveExpiresAt: archiveExpiresAt,
  isTeamTask: isTeamTask,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('SessionState', () {
    test('is authenticated only with a non-empty token and a user id', () {
      expect(const SessionState().isAuthenticated, isFalse);
      expect(
        const SessionState(jwtToken: '', userId: 'u1').isAuthenticated,
        isFalse,
      );
      expect(const SessionState(jwtToken: 'jwt').isAuthenticated, isFalse);
      expect(const SessionState(userId: 'u1').isAuthenticated, isFalse);
      expect(
        const SessionState(jwtToken: 'jwt', userId: 'u1').isAuthenticated,
        isTrue,
      );
    });
  });

  group('SessionCubit', () {
    test('setSession stores the credentials and clear removes them', () async {
      final cubit = SessionCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isAuthenticated, isFalse);

      cubit.setSession(jwtToken: 'jwt-1', userId: 'u1');
      expect(cubit.state.jwtToken, 'jwt-1');
      expect(cubit.state.userId, 'u1');
      expect(cubit.state.isAuthenticated, isTrue);

      cubit.clear();
      expect(cubit.state.jwtToken, isNull);
      expect(cubit.state.userId, isNull);
      expect(cubit.state.isAuthenticated, isFalse);
    });

    test('a new login replaces the previous session', () async {
      final cubit = SessionCubit();
      addTearDown(cubit.close);

      cubit.setSession(jwtToken: 'jwt-1', userId: 'u1');
      cubit.setSession(jwtToken: 'jwt-2', userId: 'u2');

      expect(cubit.state.jwtToken, 'jwt-2');
      expect(cubit.state.userId, 'u2');
    });
  });

  group('TaskState', () {
    test('starts empty and not initialised', () {
      const state = TaskState();

      expect(state.currentTasks, isEmpty);
      expect(state.historicalCompletions, isEmpty);
      expect(state.isInitialized, isFalse);
      expect(state.isOffline, isFalse);
      expect(state.selectedTeam, isNull);
      expect(state.dashboardStats, {
        'totalTasks': 0,
        'completedToday': 0,
        'overdueTasks': 0,
        'upcomingTasks': 0,
      });
    });

    test('a task completed today moves from active to completed', () {
      final state = TaskState(
        currentTasks: [
          _task('open'),
          _task('done', completedDays: [localToday()]),
        ],
      );

      expect(state.activeTasks.map((t) => t.id), ['open']);
      expect(state.completedTasks.map((t) => t.id), ['done']);
    });

    test('an archived task is never active', () {
      final state = TaskState(
        currentTasks: [
          _task(
            'expired',
            isArchived: true,
            archiveExpiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      );

      expect(state.activeTasks, isEmpty);
      expect(state.completedTasks, isEmpty);
    });

    test('personalTasks and teamTasks split on isTeamTask', () {
      final state = TaskState(
        currentTasks: [_task('p1'), _task('t1', isTeamTask: true), _task('p2')],
      );

      expect(state.personalTasks.map((t) => t.id), ['p1', 'p2']);
      expect(state.teamTasks.map((t) => t.id), ['t1']);
    });

    test('copyWith keeps the selected team when it is not passed', () {
      final team = Team.placeholder(id: 't1', name: 'Team One');
      final state = TaskState(selectedTeam: team);

      expect(state.copyWith(isOffline: true).selectedTeam, same(team));
    });

    test('copyWith can clear the selected team with an explicit null', () {
      final team = Team.placeholder(id: 't1', name: 'Team One');
      final state = TaskState(selectedTeam: team);

      expect(state.copyWith(selectedTeam: null).selectedTeam, isNull);
    });

    test('copyWith can switch to a different team', () {
      final a = Team.placeholder(id: 'a');
      final b = Team.placeholder(id: 'b');

      expect(
        TaskState(selectedTeam: a).copyWith(selectedTeam: b).selectedTeam,
        same(b),
      );
    });

    test('copyWith changes only the fields it is given', () {
      final tasks = [_task('1')];
      final state = TaskState(currentTasks: tasks, isInitialized: true);

      final next = state.copyWith(isOffline: true);

      expect(next.currentTasks, same(tasks));
      expect(next.isInitialized, isTrue);
      expect(next.isOffline, isTrue);
    });
  });

  group('TeamState and TeamCubit', () {
    test('copyWith keeps, clears and replaces the selected team', () {
      final team = Team.placeholder(id: 't1');
      final state = TeamState(selectedTeam: team);

      expect(state.copyWith(isOffline: true).selectedTeam, same(team));
      expect(state.copyWith(selectedTeam: null).selectedTeam, isNull);
      expect(
        state
            .copyWith(selectedTeam: Team.placeholder(id: 't2'))
            .selectedTeam
            ?.id,
        't2',
      );
    });

    test(
      'selectTeam emits the new selection and null means personal',
      () async {
        final cubit = TeamCubit();
        addTearDown(cubit.close);

        cubit.selectTeam(Team.placeholder(id: 't1', name: 'Team One'));
        expect(cubit.state.selectedTeam?.id, 't1');

        cubit.selectTeam(null);
        expect(cubit.state.selectedTeam, isNull);
      },
    );

    test('clear resets teams, invitations and selection', () async {
      final cubit = TeamCubit();
      addTearDown(cubit.close);
      cubit.selectTeam(Team.placeholder(id: 't1'));

      cubit.clear();

      expect(cubit.state.selectedTeam, isNull);
      expect(cubit.state.userTeams, isEmpty);
      expect(cubit.state.pendingInvitations, isEmpty);
    });
  });

  group('NotificationState', () {
    test('copyWith changes only what it is given', () {
      const state = NotificationState(unreadCount: 3);

      expect(state.copyWith(unreadCount: 0).unreadCount, 0);
      expect(state.copyWith(notifications: const []).unreadCount, 3);
    });
  });
}
