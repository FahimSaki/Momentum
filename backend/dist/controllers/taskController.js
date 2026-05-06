"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDashboardStats = exports.getTaskHistory = exports.getTeamTasks = exports.getUserTasks = exports.deleteTask = exports.completeTask = exports.updateTask = exports.createTask = void 0;
const Task_1 = __importDefault(require("../models/Task"));
const TaskHistory_1 = __importDefault(require("../models/TaskHistory"));
const Team_1 = __importDefault(require("../models/Team"));
const notificationService_1 = require("../services/notificationService");
const mongoose_1 = require("mongoose");
// ── Permission helpers ────────────────────────────────────────────────────
const canUserCreateTask = (team, userId) => {
    if (!team)
        return true;
    const member = team.members.find((m) => m.user.toString() === userId);
    if (!member)
        return false;
    return ['owner', 'admin'].includes(member.role);
};
const canUserEditTask = (task, team, userId) => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role))
            return true;
    }
    if (task.assignedBy?.toString() === userId)
        return true;
    return false;
};
const canUserDeleteTask = (task, team, userId) => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role))
            return true;
    }
    if (task.assignedBy?.toString() === userId)
        return true;
    return false;
};
// ── Save task to history ──────────────────────────────────────────────────
const saveTaskToHistory = async (task) => {
    if (!task.completedDays?.length)
        return;
    try {
        const assigneeIds = task.assignedTo?.length ? task.assignedTo : [];
        for (const assigneeId of assigneeIds) {
            const existing = await TaskHistory_1.default.findOne({ userId: assigneeId, taskName: task.name });
            if (existing) {
                const allDays = [...existing.completedDays, ...task.completedDays];
                const unique = [...new Set(allDays.map((d) => d.toISOString()))].map((d) => new Date(d));
                existing.completedDays = unique;
                await existing.save();
            }
            else {
                await TaskHistory_1.default.create({
                    userId: assigneeId,
                    completedDays: task.completedDays,
                    taskName: task.name,
                    teamId: task.team,
                });
            }
        }
        console.log(`Saved task "${task.name}" to history`);
    }
    catch (err) {
        console.error(`Error saving task "${task.name}" to history:`, err);
    }
};
// ── Create task ───────────────────────────────────────────────────────────
const createTask = async (req, res) => {
    try {
        const { name, description, assignedTo, teamId, priority = 'medium', dueDate, tags = [], assignmentType = 'individual', } = req.body;
        const assignerId = req.userId;
        if (!name?.trim()) {
            res.status(400).json({ message: 'Task name is required' });
            return;
        }
        let team = null;
        if (teamId) {
            team = await Team_1.default.findById(teamId);
            if (!team) {
                res.status(404).json({ message: 'Team not found' });
                return;
            }
            if (!canUserCreateTask(team, assignerId)) {
                res.status(403).json({ message: 'Only team owners and admins can create tasks.' });
                return;
            }
        }
        let assigneeIds = [];
        if (assignmentType === 'team' && team) {
            assigneeIds = team.members.map((m) => m.user);
        }
        else if (assignedTo) {
            assigneeIds = Array.isArray(assignedTo) ? assignedTo : [assignedTo];
        }
        else {
            assigneeIds = [new mongoose_1.Types.ObjectId(assignerId)];
        }
        if (teamId && team) {
            const teamMemberIds = team.members.map((m) => m.user.toString());
            const invalid = assigneeIds.filter((id) => !teamMemberIds.includes(id.toString()));
            if (invalid.length) {
                res.status(400).json({ message: 'Some assignees are not members of the team' });
                return;
            }
        }
        const task = new Task_1.default({
            name: name.trim(),
            description: description?.trim(),
            assignedTo: assigneeIds,
            assignedBy: assignerId,
            team: teamId,
            priority,
            dueDate: dueDate ? new Date(dueDate) : undefined,
            tags,
            isTeamTask: !!teamId,
            assignmentType,
        });
        await task.save();
        await task.populate([
            { path: 'assignedTo', select: 'name email avatar' },
            { path: 'assignedBy', select: 'name email avatar' },
            { path: 'team', select: 'name' },
        ]);
        const notifRecipients = assigneeIds.filter((id) => id.toString() !== assignerId);
        if (notifRecipients.length > 0) {
            try {
                await (0, notificationService_1.sendTaskAssignedNotification)(task, req.user, notifRecipients.map(String));
            }
            catch (e) {
                console.error('Notification error (non-critical):', e);
            }
        }
        res.status(201).json({ message: 'Task created successfully', task });
    }
    catch (err) {
        console.error('Create task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.createTask = createTask;
// ── Update task ───────────────────────────────────────────────────────────
const updateTask = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.userId;
        const task = await Task_1.default.findById(id).populate('team');
        if (!task) {
            res.status(404).json({ message: 'Task not found' });
            return;
        }
        let team = null;
        if (task.team)
            team = await Team_1.default.findById(task.team._id);
        if (!canUserEditTask(task, team, userId)) {
            res.status(403).json({ message: 'You do not have permission to edit this task.' });
            return;
        }
        const updated = await Task_1.default.findByIdAndUpdate(id, req.body, { new: true })
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name');
        res.json({ message: 'Task updated successfully', task: updated });
    }
    catch (err) {
        console.error('Update task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.updateTask = updateTask;
// ── Complete task ─────────────────────────────────────────────────────────
const completeTask = async (req, res) => {
    try {
        const { id } = req.params;
        const { isCompleted } = req.body;
        const userId = req.userId;
        const task = await Task_1.default.findById(id)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar');
        if (!task) {
            res.status(404).json({ message: 'Task not found' });
            return;
        }
        const isAssignee = task.assignedTo.some((a) => a._id.toString() === userId);
        if (!isAssignee) {
            res.status(403).json({ message: 'You can only complete tasks assigned to you' });
            return;
        }
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        if (isCompleted) {
            const alreadyToday = task.completedDays.some((d) => {
                const local = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                return local.getTime() === today.getTime();
            });
            if (!alreadyToday) {
                task.completedDays.push(today);
                task.lastCompletedDate = today;
                task.isArchived = true;
                task.archivedAt = new Date();
                const existing = task.completedBy.find((c) => c.user.toString() === userId);
                if (!existing)
                    task.completedBy.push({ user: new mongoose_1.Types.ObjectId(userId), completedAt: new Date() });
            }
        }
        else {
            task.completedDays = task.completedDays.filter((d) => {
                const local = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                return local.getTime() !== today.getTime();
            });
            task.completedBy = task.completedBy.filter((c) => {
                if (c.user.toString() !== userId)
                    return true;
                const cd = new Date(c.completedAt.getFullYear(), c.completedAt.getMonth(), c.completedAt.getDate());
                return cd.getTime() !== today.getTime();
            });
            const otherToday = task.completedBy.some((c) => {
                const cd = new Date(c.completedAt.getFullYear(), c.completedAt.getMonth(), c.completedAt.getDate());
                return cd.getTime() === today.getTime();
            });
            if (!otherToday) {
                task.isArchived = false;
                task.archivedAt = undefined;
            }
            task.lastCompletedDate = task.completedDays.length
                ? task.completedDays.reduce((a, b) => (a > b ? a : b))
                : undefined;
        }
        await task.save();
        if (isCompleted && task.assignedBy && task.assignedBy._id?.toString() !== userId) {
            try {
                await (0, notificationService_1.sendTaskCompletedNotification)(task, req.user, task.assignedBy._id);
            }
            catch (e) {
                console.error('Notification error (non-critical):', e);
            }
        }
        await task.populate([{ path: 'completedBy.user', select: 'name email avatar' }, { path: 'team', select: 'name' }]);
        res.json({ message: `Task ${isCompleted ? 'completed' : 'unmarked'} successfully`, task });
    }
    catch (err) {
        console.error('Complete task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.completeTask = completeTask;
// ── Delete task ───────────────────────────────────────────────────────────
const deleteTask = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.userId;
        const task = await Task_1.default.findById(id);
        if (!task) {
            res.status(404).json({ message: 'Task not found' });
            return;
        }
        let team = null;
        if (task.team)
            team = await Team_1.default.findById(task.team);
        if (!canUserDeleteTask(task, team, userId)) {
            res.status(403).json({ message: 'You do not have permission to delete this task.' });
            return;
        }
        await saveTaskToHistory(task);
        await task.deleteOne();
        res.json({ message: 'Task deleted successfully and preserved in history' });
    }
    catch (err) {
        console.error('Delete task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.deleteTask = deleteTask;
// ── Get user tasks ────────────────────────────────────────────────────────
const getUserTasks = async (req, res) => {
    try {
        const { userId, teamId, type = 'all' } = req.query;
        const requesterId = req.userId;
        let query = {};
        if (type === 'personal') {
            query = { assignedTo: userId || requesterId, team: { $exists: false } };
        }
        else if (type === 'team' && teamId) {
            query = { team: teamId, assignedTo: userId || requesterId };
        }
        else {
            query = { assignedTo: userId || requesterId };
        }
        const tasks = await Task_1.default.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name')
            .populate({ path: 'completedBy.user', select: 'name email avatar' })
            .sort({ createdAt: -1 });
        const cleaned = tasks.map((t) => {
            const obj = t.toObject();
            if (obj.completedBy?.length) {
                obj.completedBy = obj.completedBy.map((c) => ({
                    user: c.user || { _id: 'unknown', name: 'Unknown User', email: '', avatar: null },
                    completedAt: c.completedAt,
                }));
            }
            return obj;
        });
        res.json(cleaned);
    }
    catch (err) {
        console.error('Get user tasks error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getUserTasks = getUserTasks;
// ── Get team tasks ────────────────────────────────────────────────────────
const getTeamTasks = async (req, res) => {
    try {
        const { teamId } = req.params;
        const { status = 'active' } = req.query;
        const userId = req.userId;
        const team = await Team_1.default.findById(teamId);
        if (!team) {
            res.status(404).json({ message: 'Team not found' });
            return;
        }
        const isMember = team.members.some((m) => m.user.toString() === userId);
        if (!isMember) {
            res.status(403).json({ message: 'Access denied' });
            return;
        }
        const query = { team: teamId };
        if (status === 'active')
            query.isArchived = false;
        else if (status === 'archived')
            query.isArchived = true;
        const tasks = await Task_1.default.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate({ path: 'completedBy.user', select: 'name email avatar' })
            .populate('team', 'name')
            .sort({ createdAt: -1 });
        res.json(tasks);
    }
    catch (err) {
        console.error('Get team tasks error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getTeamTasks = getTeamTasks;
// ── Get task history ──────────────────────────────────────────────────────
const getTaskHistory = async (req, res) => {
    try {
        const { userId, teamId } = req.query;
        const requesterId = req.userId;
        let query = {};
        if (teamId) {
            const team = await Team_1.default.findById(teamId);
            if (!team) {
                res.status(404).json({ message: 'Team not found' });
                return;
            }
            const isMember = team.members.some((m) => m.user.toString() === requesterId);
            if (!isMember) {
                res.status(403).json({ message: 'Access denied' });
                return;
            }
            query.teamId = teamId;
        }
        else {
            query.userId = userId || requesterId;
        }
        const history = await TaskHistory_1.default.find(query)
            .populate('userId', 'name email avatar')
            .populate('teamId', 'name')
            .sort({ createdAt: -1 });
        res.json(history);
    }
    catch (err) {
        console.error('Get task history error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getTaskHistory = getTaskHistory;
// ── Dashboard stats ───────────────────────────────────────────────────────
const getDashboardStats = async (req, res) => {
    try {
        const { teamId } = req.query;
        const userId = req.userId;
        const query = { assignedTo: userId };
        if (teamId)
            query.team = teamId;
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const [totalTasks, completedToday, overdueTasks, upcomingTasks] = await Promise.all([
            Task_1.default.countDocuments({ ...query, isArchived: false }),
            Task_1.default.countDocuments({
                ...query,
                completedDays: { $elemMatch: { $gte: today, $lt: new Date(today.getTime() + 86400000) } },
            }),
            Task_1.default.countDocuments({ ...query, dueDate: { $lt: today }, isArchived: false }),
            Task_1.default.countDocuments({
                ...query,
                dueDate: { $gte: today, $lte: new Date(today.getTime() + 7 * 86400000) },
                isArchived: false,
            }),
        ]);
        res.json({ totalTasks, completedToday, overdueTasks, upcomingTasks });
    }
    catch (err) {
        console.error('Dashboard stats error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getDashboardStats = getDashboardStats;
//# sourceMappingURL=taskController.js.map