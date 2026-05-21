import { Request, Response } from 'express';
import Task from '../models/Task';
import TaskHistory from '../models/TaskHistory';
import Team from '../models/Team';
import { sendTaskAssignedNotification, sendTaskCompletedNotification } from '../services/notificationService';
import { ITaskDocument, ITeamDocument } from '../types/interfaces';
import { Types } from 'mongoose';

// ── Permission helpers ────────────────────────────────────────────────────

const canUserCreateTask = (team: ITeamDocument, userId: string): boolean => {
    if (!team) return true;
    const member = team.members.find((m) => m.user.toString() === userId);
    if (!member) return false;
    return ['owner', 'admin'].includes(member.role);
};

const canUserEditTask = (task: ITaskDocument, team: ITeamDocument | null, userId: string): boolean => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role)) return true;
    }
    if (task.assignedBy?.toString() === userId) return true;
    return false;
};

const canUserDeleteTask = (task: ITaskDocument, team: ITeamDocument | null, userId: string): boolean => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role)) return true;
    }
    if (task.assignedBy?.toString() === userId) return true;
    return false;
};

// ── Save task to history ──────────────────────────────────────────────────

const saveTaskToHistory = async (task: ITaskDocument): Promise<void> => {
    if (!task.completedDays?.length) return;
    try {
        const assigneeIds = task.assignedTo?.length ? task.assignedTo : [];
        for (const assigneeId of assigneeIds) {
            const existing = await TaskHistory.findOne({ userId: assigneeId, taskName: task.name });
            if (existing) {
                const allDays = [...existing.completedDays, ...task.completedDays];
                const unique = [...new Set(allDays.map((d) => d.toISOString()))].map((d) => new Date(d));
                existing.completedDays = unique;
                await existing.save();
            } else {
                await TaskHistory.create({
                    userId: assigneeId,
                    completedDays: task.completedDays,
                    taskName: task.name,
                    teamId: task.team,
                });
            }
        }
        console.log(`Saved task "${task.name}" to history`);
    } catch (err) {
        console.error(`Error saving task "${task.name}" to history:`, err);
    }
};

// ── Create task ───────────────────────────────────────────────────────────

export const createTask = async (req: Request, res: Response): Promise<void> => {
    try {
        console.log('🟢 TASK CREATE HIT', { userId: req.userId, body: req.body });
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

        let team: ITeamDocument | null = null;
        if (teamId) {
            team = await Team.findById(teamId);
            if (!team) { res.status(404).json({ message: 'Team not found' }); return; }
            if (!canUserCreateTask(team, assignerId)) {
                res.status(403).json({ message: 'Only team owners and admins can create tasks.' });
                return;
            }
        }

        let assigneeIds: Types.ObjectId[] = [];
        if (assignmentType === 'team' && team) {
            assigneeIds = team.members.map((m) => m.user as Types.ObjectId);
        } else if (assignedTo) {
            assigneeIds = Array.isArray(assignedTo) ? assignedTo : [assignedTo];
        } else {
            assigneeIds = [new Types.ObjectId(assignerId)];
        }

        if (teamId && team) {
            const teamMemberIds = team.members.map((m) => m.user.toString());
            const invalid = assigneeIds.filter((id) => !teamMemberIds.includes(id.toString()));
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

        const notifRecipients = assigneeIds.filter((id) => id.toString() !== assignerId);
        console.log('📩 notifRecipients:', notifRecipients.length, notifRecipients);
        if (notifRecipients.length > 0) {
            try {
                console.log('📡 calling sendTaskAssignedNotification');
                await sendTaskAssignedNotification(task, req.user, notifRecipients.map(String));
            }
            catch (e) { console.error('Notification error (non-critical):', e); }
        } else {
            console.log('⚠️ No recipients to notify — skipping FCM');
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

        const task = await Task.findById(id).populate('team');
        if (!task) { res.status(404).json({ message: 'Task not found' }); return; }

        let team: ITeamDocument | null = null;
        if (task.team) team = await Team.findById((task.team as any)._id);

        if (!canUserEditTask(task, team, userId)) {
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

        //  const now = new Date();
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
                if (!existing) task.completedBy.push({ user: new Types.ObjectId(userId), completedAt: new Date() });
            }
        } else {
            task.completedDays = task.completedDays.filter((d) => {
                const local = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                return local.getTime() !== today.getTime();
            });
            task.completedBy = task.completedBy.filter((c) => {
                if (c.user.toString() !== userId) return true;
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

        // Fixed — notify ALL assignees except the completer:
        if (isCompleted) {
            const toNotify = task.assignedTo
                .map((a: any) => a._id?.toString() ?? a.toString())
                .filter((id: string) => id !== userId);

            if (task.assignedBy) {
                const assignerIdStr = (task.assignedBy as any)._id?.toString()
                    ?? task.assignedBy.toString();
                if (!toNotify.includes(assignerIdStr)) toNotify.push(assignerIdStr);
            }

            for (const recipientId of toNotify) {
                try {
                    await sendTaskCompletedNotification(task, req.user, recipientId);
                }
                catch (e) { console.error('Notification error (non-critical):', e); }
            }
        }

        await task.populate([{ path: 'completedBy.user', select: 'name email avatar' }, { path: 'team', select: 'name' }]);

        res.json({ message: `Task ${isCompleted ? 'completed' : 'unmarked'} successfully`, task });
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

        let team: ITeamDocument | null = null;
        if (task.team) team = await Team.findById(task.team);

        if (!canUserDeleteTask(task, team, userId)) {
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
                    user: c.user || { _id: 'unknown', name: 'Unknown User', email: '', avatar: null },
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
        const isPrivilegedMember = member && ['owner', 'admin'].includes(member.role);

        const query: Record<string, any> = { team: teamId };
        if (!isPrivilegedMember) {
            query.assignedTo = userId;
        }
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

        const [totalTasks, completedToday, overdueTasks, upcomingTasks] = await Promise.all([
            Task.countDocuments({ ...query, isArchived: false }),
            Task.countDocuments({
                ...query,
                completedDays: { $elemMatch: { $gte: today, $lt: new Date(today.getTime() + 86400000) } },
            }),
            Task.countDocuments({ ...query, dueDate: { $lt: today }, isArchived: false }),
            Task.countDocuments({
                ...query,
                dueDate: { $gte: today, $lte: new Date(today.getTime() + 7 * 86400000) },
                isArchived: false,
            }),
        ]);

        res.json({ totalTasks, completedToday, overdueTasks, upcomingTasks });
    } catch (err) {
        console.error('Dashboard stats error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};