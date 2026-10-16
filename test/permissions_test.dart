import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/helpers/permission_helper.dart';
import 'package:momentum/models/notification_settings.dart';
import 'package:momentum/models/task.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/models/team_member.dart';
import 'package:momentum/models/team_permissions.dart';
import 'package:momentum/models/team_settings.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/utils/priority_helpers.dart';
import 'package:momentum/utils/role_helpers.dart';

User _user(String id) => User.placeholder(id: id, name: 'User $id');

TeamMember _member(String id, String role) =>
    TeamMember(user: _user(id), role: role, joinedAt: DateTime(2026, 1, 1));

Team _team() => Team(
  id: 't1',
  name: 'Team One',
  owner: _user('owner1'),
  members: [
    _member('owner1', 'owner'),
    _member('admin1', 'admin'),
    _member('member1', 'member'),
  ],
  settings: TeamSettings(notificationSettings: NotificationSettings()),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Task _taskBy(String? creatorId) => Task(
  id: 'task1',
  name: 'Task',
  assignedBy: creatorId == null ? null : _user(creatorId),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('TeamPermissions', () {
    test('forRole maps each role and is case-insensitive', () {
      expect(TeamPermissions.forRole('owner'), same(TeamPermissions.owner));
      expect(TeamPermissions.forRole('ADMIN'), same(TeamPermissions.admin));
      expect(TeamPermissions.forRole('member'), same(TeamPermissions.member));
    });

    test('an unknown or empty role gets member permissions', () {
      expect(
        TeamPermissions.forRole('superuser'),
        same(TeamPermissions.member),
      );
      expect(TeamPermissions.forRole(''), same(TeamPermissions.member));
    });

    test('only the owner can delete the team', () {
      expect(TeamPermissions.owner.canDeleteTeam, isTrue);
      expect(TeamPermissions.admin.canDeleteTeam, isFalse);
      expect(TeamPermissions.member.canDeleteTeam, isFalse);
    });

    test('owners and admins manage tasks and members', () {
      for (final p in [TeamPermissions.owner, TeamPermissions.admin]) {
        expect(p.canCreateTasks, isTrue);
        expect(p.canEditAllTasks, isTrue);
        expect(p.canDeleteAllTasks, isTrue);
        expect(p.canAssignTasks, isTrue);
        expect(p.canInviteMembers, isTrue);
        expect(p.canRemoveMembers, isTrue);
        expect(p.canEditSettings, isTrue);
      }
    });

    test('members can view and complete every task but change nothing', () {
      const p = TeamPermissions.member;
      expect(p.canViewTasks, isTrue);
      expect(p.canCompleteTasks, isTrue);
      expect(p.canCreateTasks, isFalse);
      expect(p.canEditOwnTasks, isFalse);
      expect(p.canEditAllTasks, isFalse);
      expect(p.canDeleteOwnTasks, isFalse);
      expect(p.canDeleteAllTasks, isFalse);
      expect(p.canAssignTasks, isFalse);
      expect(p.canInviteMembers, isFalse);
      expect(p.canEditSettings, isFalse);
    });

    test('owners and admins can edit and delete anyone\'s task', () {
      for (final p in [TeamPermissions.owner, TeamPermissions.admin]) {
        expect(p.canEditTask('someone-else', 'me'), isTrue);
        expect(p.canDeleteTask('someone-else', 'me'), isTrue);
      }
    });

    test('a member cannot edit or delete, not even their own task', () {
      expect(TeamPermissions.member.canEditTask('me', 'me'), isFalse);
      expect(TeamPermissions.member.canDeleteTask('me', 'me'), isFalse);
    });
  });

  group('PermissionHelper', () {
    test('getUserRole reads owner, admin and member roles', () {
      final team = _team();
      expect(PermissionHelper.getUserRole(team, 'owner1'), 'owner');
      expect(PermissionHelper.getUserRole(team, 'admin1'), 'admin');
      expect(PermissionHelper.getUserRole(team, 'member1'), 'member');
    });

    test('a user who is not on the team is treated as a plain member', () {
      final team = _team();
      expect(PermissionHelper.getUserRole(team, 'stranger'), 'member');
      expect(
        PermissionHelper.getUserPermissions(team, 'stranger'),
        same(TeamPermissions.member),
      );
    });

    test('getUserPermissions follows the role', () {
      final team = _team();
      expect(
        PermissionHelper.getUserPermissions(team, 'admin1'),
        same(TeamPermissions.admin),
      );
    });

    test('canUserCompleteTask needs team membership only', () {
      final team = _team();
      expect(PermissionHelper.canUserCompleteTask(team, 'member1'), isTrue);
      expect(PermissionHelper.canUserCompleteTask(team, 'stranger'), isFalse);
    });

    test('canUserEditTask and canUserDeleteTask follow the role', () {
      final team = _team();
      final byMember = _taskBy('member1');

      expect(
        PermissionHelper.canUserEditTask(team, byMember, 'admin1'),
        isTrue,
      );
      expect(
        PermissionHelper.canUserEditTask(team, byMember, 'member1'),
        isFalse,
      );
      expect(
        PermissionHelper.canUserDeleteTask(team, byMember, 'owner1'),
        isTrue,
      );
      expect(
        PermissionHelper.canUserDeleteTask(team, byMember, 'member1'),
        isFalse,
      );
    });

    test('a task with no creator can still be edited by an admin', () {
      final team = _team();
      expect(
        PermissionHelper.canUserEditTask(team, _taskBy(null), 'admin1'),
        isTrue,
      );
    });
  });

  group('Team', () {
    test('isOwner, isAdmin and isMember', () {
      final team = _team();

      expect(team.isOwner('owner1'), isTrue);
      expect(team.isOwner('admin1'), isFalse);

      expect(team.isAdmin('owner1'), isTrue);
      expect(team.isAdmin('admin1'), isTrue);
      expect(team.isAdmin('member1'), isFalse);
      expect(team.isAdmin('stranger'), isFalse);

      expect(team.isMember('member1'), isTrue);
      expect(team.isMember('stranger'), isFalse);
    });

    test('getMember returns the member or null', () {
      final team = _team();
      expect(team.getMember('admin1')?.role, 'admin');
      expect(team.getMember('stranger'), isNull);
    });

    test('TeamMember role shortcuts', () {
      expect(_member('a', 'owner').canInvite, isTrue);
      expect(_member('a', 'admin').canInvite, isTrue);
      expect(_member('a', 'member').canInvite, isFalse);
      expect(_member('a', 'admin').canDeleteTasks, isTrue);
      expect(_member('a', 'member').canDeleteTasks, isFalse);
      expect(_member('a', 'owner').isOwner, isTrue);
      expect(_member('a', 'member').isMember, isTrue);
    });
  });

  group('RoleHelpers', () {
    test('displayName is case-insensitive and defaults to Member', () {
      expect(RoleHelpers.displayName('owner'), 'Owner');
      expect(RoleHelpers.displayName('ADMIN'), 'Admin');
      expect(RoleHelpers.displayName('member'), 'Member');
      expect(RoleHelpers.displayName('whatever'), 'Member');
    });

    test('each role has its own colour', () {
      final colours = {
        RoleHelpers.color('owner'),
        RoleHelpers.color('admin'),
        RoleHelpers.color('member'),
      };
      expect(colours.length, 3);
      expect(RoleHelpers.color('owner'), const Color(0xFF8B5CF6));
    });

    test('every role has a description and an icon', () {
      for (final role in ['owner', 'admin', 'member']) {
        expect(RoleHelpers.description(role), isNotEmpty);
        expect(RoleHelpers.icon(role), isA<IconData>());
        expect(RoleHelpers.gradient(role).length, 2);
      }
    });
  });

  group('PriorityHelpers', () {
    test('known priorities have fixed colours and ignore case', () {
      expect(PriorityHelpers.color('low'), const Color(0xFF22C55E));
      expect(PriorityHelpers.color('urgent'), const Color(0xFFE53E3E));
      expect(PriorityHelpers.color('URGENT'), PriorityHelpers.color('urgent'));
    });

    test('an unknown priority falls back to grey', () {
      expect(PriorityHelpers.color('someday'), Colors.grey);
    });
  });
}
