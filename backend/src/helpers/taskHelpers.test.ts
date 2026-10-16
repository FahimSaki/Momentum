import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canCreateTask, canEditTask, canDeleteTask } from './taskHelpers';

// Plain objects stand in for Mongoose documents: the helpers only read
// team.members[].user/role and task.assignedBy.
const team = (members: Array<[string, 'owner' | 'admin' | 'member']>): any => ({
    members: members.map(([user, role]) => ({ user, role })),
});
const task = (assignedBy?: string): any => ({ assignedBy });

const t = team([
    ['owner1', 'owner'],
    ['admin1', 'admin'],
    ['member1', 'member'],
    ['member2', 'member'],
]);

test('anyone can create a personal task', () => {
    assert.equal(canCreateTask(null, 'anyone'), true);
});

test('only owners and admins can create team tasks', () => {
    assert.equal(canCreateTask(t, 'owner1'), true);
    assert.equal(canCreateTask(t, 'admin1'), true);
    assert.equal(canCreateTask(t, 'member1'), false);
});

test('a non-member cannot create team tasks', () => {
    assert.equal(canCreateTask(t, 'stranger'), false);
});

test('owners and admins can edit any team task', () => {
    assert.equal(canEditTask(task('member1'), t, 'owner1'), true);
    assert.equal(canEditTask(task('member1'), t, 'admin1'), true);
});

test('a member can edit only a task they created', () => {
    assert.equal(canEditTask(task('member1'), t, 'member1'), true);
    assert.equal(canEditTask(task('member2'), t, 'member1'), false);
});

test('a non-member cannot edit a team task', () => {
    assert.equal(canEditTask(task('owner1'), t, 'stranger'), false);
});

test('on a personal task only its creator can edit', () => {
    assert.equal(canEditTask(task('u1'), null, 'u1'), true);
    assert.equal(canEditTask(task('u1'), null, 'u2'), false);
});

test('a task with no creator can be edited by owners and admins but not members', () => {
    assert.equal(canEditTask(task(undefined), t, 'admin1'), true);
    assert.equal(canEditTask(task(undefined), t, 'member1'), false);
});

test('delete follows exactly the same rules as edit', () => {
    const cases: Array<[any, any, string]> = [
        [task('member1'), t, 'owner1'],
        [task('member1'), t, 'member1'],
        [task('member2'), t, 'member1'],
        [task('u1'), null, 'u1'],
        [task('u1'), null, 'u2'],
    ];
    for (const [tk, tm, user] of cases) {
        assert.equal(canDeleteTask(tk, tm, user), canEditTask(tk, tm, user));
    }
});