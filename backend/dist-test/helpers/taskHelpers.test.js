"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = require("node:test");
const strict_1 = __importDefault(require("node:assert/strict"));
const taskHelpers_1 = require("./taskHelpers");
// Plain objects stand in for Mongoose documents: the helpers only read
// team.members[].user/role and task.assignedBy.
const team = (members) => ({
    members: members.map(([user, role]) => ({ user, role })),
});
const task = (assignedBy) => ({ assignedBy });
const t = team([
    ['owner1', 'owner'],
    ['admin1', 'admin'],
    ['member1', 'member'],
    ['member2', 'member'],
]);
(0, node_test_1.test)('anyone can create a personal task', () => {
    strict_1.default.equal((0, taskHelpers_1.canCreateTask)(null, 'anyone'), true);
});
(0, node_test_1.test)('only owners and admins can create team tasks', () => {
    strict_1.default.equal((0, taskHelpers_1.canCreateTask)(t, 'owner1'), true);
    strict_1.default.equal((0, taskHelpers_1.canCreateTask)(t, 'admin1'), true);
    strict_1.default.equal((0, taskHelpers_1.canCreateTask)(t, 'member1'), false);
});
(0, node_test_1.test)('a non-member cannot create team tasks', () => {
    strict_1.default.equal((0, taskHelpers_1.canCreateTask)(t, 'stranger'), false);
});
(0, node_test_1.test)('owners and admins can edit any team task', () => {
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('member1'), t, 'owner1'), true);
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('member1'), t, 'admin1'), true);
});
(0, node_test_1.test)('a member can edit only a task they created', () => {
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('member1'), t, 'member1'), true);
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('member2'), t, 'member1'), false);
});
(0, node_test_1.test)('a non-member cannot edit a team task', () => {
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('owner1'), t, 'stranger'), false);
});
(0, node_test_1.test)('on a personal task only its creator can edit', () => {
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('u1'), null, 'u1'), true);
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task('u1'), null, 'u2'), false);
});
(0, node_test_1.test)('a task with no creator can be edited by owners and admins but not members', () => {
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task(undefined), t, 'admin1'), true);
    strict_1.default.equal((0, taskHelpers_1.canEditTask)(task(undefined), t, 'member1'), false);
});
(0, node_test_1.test)('delete follows exactly the same rules as edit', () => {
    const cases = [
        [task('member1'), t, 'owner1'],
        [task('member1'), t, 'member1'],
        [task('member2'), t, 'member1'],
        [task('u1'), null, 'u1'],
        [task('u1'), null, 'u2'],
    ];
    for (const [tk, tm, user] of cases) {
        strict_1.default.equal((0, taskHelpers_1.canDeleteTask)(tk, tm, user), (0, taskHelpers_1.canEditTask)(tk, tm, user));
    }
});
