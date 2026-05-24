import { Request, Response } from 'express';
import Task from '../models/Task';
import TaskHistory from '../models/TaskHistory';
import Team from '../models/Team';
import {
    canCreateTask,
    canEditTask,
    canDeleteTask,
    saveTaskToHistory,
    getTaskTeam,
} from '../helpers/taskHelpers';
import {
    sendTaskAssignedNotification,
    sendTaskCompletedNotification,
} from '../services/notificationService';
import { ITaskDocument } from '../types/interfaces';
import { Types } from 'mongoose';

// ── Create task ───────────────────────────────────────────────────────────

export const createTask = async (req: Request, res: Response): Promise<void> => {
    try {
        const {
            name,
            description,
            assignedTo,
            teamId,
            priority = 'medium',
            dueDate,
            tags = [],
            assignmentType = 'individual',
        } = req.body;
        const assignerId = req.userId;

        if (!name?.trim()) {
            res.status(400).json({ message: 'Task name is required' });
            return;
        }

        const team = teamId ? await Team.findById(teamId) : null;
        if (teamId && !team) {
            res.status(404).json({ message: 'Team not found' });
            return;
        }
        if (!canCreateTask(team, assignerId)) {
            res.status(403).json({ message: 'Only team owners and admins can create tasks.' });
            return;
        }

        let assigneeIds: Types.ObjectId[] = [];
        if (assignmentType === 'team' && team) {
            assigneeIds = team.members.map((m) => m.user as Types.ObjectId);
        } else if (assignedTo) {
            assigneeIds = Array.isArray(assignedTo) ? assignedTo : [assignedTo];
        } else {
            assigneeIds = [new Types.ObjectId(assignerId)];
        }

        if (team) {
            const memberIds = team.members.map((m) => m.user.toString());
            const invalid = assigneeIds.filter((id) => !memberIds.includes(id.toString()));
            if (invalid.length) {
                res.status(400).json({ message: 'Some assignees are not members of the team' });
                return;
            }
        }

        const task = new Task({
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

        const notifRecipients = assigneeIds
            .map(String)
            .filter((id) => id !== assignerId);
        if (notifRecipients.length > 0) {
            try {
                await sendTaskAssignedNotification(task, req.user, notifRecipients);
            } catch (e) {
                console.error('Notification error (non-critical):', e);
            }
        }

        res.status(201).json({ message: 'Task created successfully', task });
    } catch (err) {
        console.error('Create task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Update task ───────────────────────────────────────────────────────────

export const updateTask = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const userId = req.userId;

        const task = await Task.findById(id);
        if (!task) { res.status(404).json({ message: 'Task not found' }); return; }

        const team = await getTaskTeam(task);
        if (!canEditTask(task, team, userId)) {
            res.status(403).json({ message: 'You do not have permission to edit this task.' });
            return;
        }

        const updated = await Task.findByIdAndUpdate(id, req.body, { new: true })
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name');

        res.json({ message: 'Task updated successfully', task: updated });
    } catch (err) {
        console.error('Update task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Complete task ─────────────────────────────────────────────────────────

export const completeTask = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const { isCompleted } = req.body as { isCompleted: boolean };
        const userId = req.userId;

        const task = await Task.findById(id)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar');
        if (!task) { res.status(404).json({ message: 'Task not found' }); return; }

        const isAssignee = task.assignedTo.some((a: any) => a._id.toString() === userId);
        if (!isAssignee) {
            res.status(403).json({ message: 'You can only complete tasks assigned to you' });
            return;
        }

        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

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
                if (!existing) {
                    task.completedBy.push({
                        user: new Types.ObjectId(userId),
                        completedAt: new Date(),
                    });
                }
            }
        } else {
            task.completedDays = task.completedDays.filter((d) => {
                const local = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                return local.getTime() !== today.getTime();
            });
            task.completedBy = task.completedBy.filter((c) => {
                if (c.user.toString() !== userId) return true;
                const cd = new Date(
                    c.completedAt.getFullYear(),
                    c.completedAt.getMonth(),
                    c.completedAt.getDate()
                );
                return cd.getTime() !== today.getTime();
            });
            const otherToday = task.completedBy.some((c) => {
                const cd = new Date(
                    c.completedAt.getFullYear(),
                    c.completedAt.getMonth(),
                    c.completedAt.getDate()
                );
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

        if (isCompleted) {
            const toNotify = task.assignedTo
                .map((a: any) => a._id?.toString() ?? a.toString())
                .filter((id: string) => id !== userId);
            if (task.assignedBy) {
                const assignerId = (task.assignedBy as any)._id?.toString() ?? task.assignedBy.toString();
                if (!toNotify.includes(assignerId)) toNotify.push(assignerId);
            }
            for (const recipientId of toNotify) {
                try {
                    await sendTaskCompletedNotification(task, req.user, recipientId);
                } catch (e) {
                    console.error('Notification error (non-critical):', e);
                }
            }
        }

        await task.populate([
            { path: 'completedBy.user', select: 'name email avatar' },
            { path: 'team', select: 'name' },
        ]);

        res.json({
            message: `Task ${isCompleted ? 'completed' : 'unmarked'} successfully`,
            task,
        });
    } catch (err) {
        console.error('Complete task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Delete task ───────────────────────────────────────────────────────────

export const deleteTask = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const userId = req.userId;

        const task = await Task.findById(id);
        if (!task) { res.status(404).json({ message: 'Task not found' }); return; }

        const team = await getTaskTeam(task);
        if (!canDeleteTask(task, team, userId)) {
            res.status(403).json({ message: 'You do not have permission to delete this task.' });
            return;
        }

        await saveTaskToHistory(task);
        await task.deleteOne();

        res.json({ message: 'Task deleted successfully and preserved in history' });
    } catch (err) {
        console.error('Delete task error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get user tasks ────────────────────────────────────────────────────────

export const getUserTasks = async (req: Request, res: Response): Promise<void> => {
    try {
        const { userId, teamId, type = 'all' } = req.query as Record<string, string>;
        const requesterId = req.userId;

        let query: Record<string, any> = {};
        if (type === 'personal') {
            query = { assignedTo: userId || requesterId, team: { $exists: false } };
        } else if (type === 'team' && teamId) {
            query = { team: teamId, assignedTo: userId || requesterId };
        } else {
            query = { assignedTo: userId || requesterId };
        }

        const tasks = await Task.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name')
            .populate({ path: 'completedBy.user', select: 'name email avatar' })
            .sort({ createdAt: -1 });

        const cleaned = tasks.map((t) => {
            const obj = t.toObject();
            if (obj.completedBy?.length) {
                obj.completedBy = obj.completedBy.map((c: any) => ({
                    user: c.user || {
                        _id: 'unknown',
                        name: 'Unknown User',
                        email: '',
                        avatar: null,
                    },
                    completedAt: c.completedAt,
                }));
            }
            return obj;
        });

        res.json(cleaned);
    } catch (err) {
        console.error('Get user tasks error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get team tasks ────────────────────────────────────────────────────────

export const getTeamTasks = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const { status = 'active' } = req.query as { status?: string };
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const isMember = team.members.some((m) => m.user.toString() === userId);
        if (!isMember) { res.status(403).json({ message: 'Access denied' }); return; }

        const member = team.members.find((m) => m.user.toString() === userId);
        const isPrivileged = member && ['owner', 'admin'].includes(member.role);

        const query: Record<string, any> = { team: teamId };
        if (!isPrivileged) query.assignedTo = userId;

        if (status === 'active') {
            const todayStart = new Date();
            todayStart.setUTCHours(0, 0, 0, 0);
            query.$or = [
                { isArchived: false },
                { isArchived: true, archivedAt: { $gte: todayStart } },
            ];
        } else if (status === 'archived') {
            query.isArchived = true;
        }

        const tasks = await Task.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate({ path: 'completedBy.user', select: 'name email avatar' })
            .populate('team', 'name')
            .sort({ createdAt: -1 });

        res.json(tasks);
    } catch (err) {
        console.error('Get team tasks error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get task history ──────────────────────────────────────────────────────

export const getTaskHistory = async (req: Request, res: Response): Promise<void> => {
    try {
        const { userId, teamId } = req.query as Record<string, string>;
        const requesterId = req.userId;

        let query: Record<string, any> = {};
        if (teamId) {
            const team = await Team.findById(teamId);
            if (!team) { res.status(404).json({ message: 'Team not found' }); return; }
            const isMember = team.members.some((m) => m.user.toString() === requesterId);
            if (!isMember) { res.status(403).json({ message: 'Access denied' }); return; }
            query.teamId = teamId;
        } else {
            query.userId = userId || requesterId;
        }

        const history = await TaskHistory.find(query)
            .populate('userId', 'name email avatar')
            .populate('teamId', 'name')
            .sort({ createdAt: -1 });

        res.json(history);
    } catch (err) {
        console.error('Get task history error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Dashboard stats ───────────────────────────────────────────────────────

export const getDashboardStats = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.query as { teamId?: string };
        const userId = req.userId;

        const query: Record<string, any> = { assignedTo: userId };
        if (teamId) query.team = teamId;

        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const tomorrow = new Date(today.getTime() + 86400000);
        const nextWeek = new Date(today.getTime() + 7 * 86400000);

        const [totalTasks, completedToday, overdueTasks, upcomingTasks] =
            await Promise.all([
                Task.countDocuments({ ...query, isArchived: false }),
                Task.countDocuments({
                    ...query,
                    completedDays: { $elemMatch: { $gte: today, $lt: tomorrow } },
                }),
                Task.countDocuments({
                    ...query,
                    dueDate: { $lt: today },
                    isArchived: false,
                }),
                Task.countDocuments({
                    ...query,
                    dueDate: { $gte: today, $lte: nextWeek },
                    isArchived: false,
                }),
            ]);

        res.json({ totalTasks, completedToday, overdueTasks, upcomingTasks });
    } catch (err) {
        console.error('Dashboard stats error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};