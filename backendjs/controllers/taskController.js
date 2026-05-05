import Task from '../models/Task.js';
import TaskHistory from '../models/TaskHistory.js';
import Team from '../models/Team.js';
import User from '../models/User.js';
import { sendTaskAssignedNotification, sendTaskCompletedNotification } from '../services/notificationService.js';

// PERMISSION HELPER FUNCTIONS
const canUserCreateTask = (team, userId) => {
    if (!team) return true; // Personal tasks allowed
    const member = team.members.find(m => m.user.toString() === userId);
    if (!member) return false;
    return ['owner', 'admin'].includes(member.role);
};

const canUserEditTask = (task, team, userId) => {
    // Owner/admin can edit all tasks
    if (team) {
        const member = team.members.find(m => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role)) return true;
    }

    // Task creator can edit their own tasks
    if (task.assignedBy?.toString() === userId) return true;

    // Members cannot edit tasks
    return false;
};

const canUserDeleteTask = (task, team, userId) => {
    // Owner/admin can delete all tasks
    if (team) {
        const member = team.members.find(m => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role)) return true;
    }

    // Task creator can delete their own tasks
    if (task.assignedBy?.toString() === userId) return true;

    return false;
};

// Helper function to save task to history before deletion
const saveTaskToHistory = async (task) => {
    if (task.completedDays?.length > 0) {
        try {
            const assigneeIds = task.assignedTo && task.assignedTo.length > 0
                ? task.assignedTo
                : [task.assignedTo].filter(Boolean);

            for (const assigneeId of assigneeIds) {
                const existingHistory = await TaskHistory.findOne({
                    userId: assigneeId,
                    taskName: task.name
                });

                if (existingHistory) {
                    const allDays = [...existingHistory.completedDays, ...task.completedDays];
                    const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))].map(d => new Date(d));
                    existingHistory.completedDays = uniqueDays;
                    await existingHistory.save();
                } else {
                    await TaskHistory.create({
                        userId: assigneeId,
                        completedDays: task.completedDays,
                        taskName: task.name,
                        teamId: task.team
                    });
                }
            }
            console.log(`Saved task "${task.name}" to history for ${assigneeIds.length} users`);
        } catch (error) {
            console.error(`Error saving task "${task.name}" to history:`, error);
        }
    }
};

// Create a new task - WITH PERMISSION CHECK
export const createTask = async (req, res) => {
    try {
        const {
            name,
            description,
            assignedTo,
            teamId,
            priority = 'medium',
            dueDate,
            tags = [],
            assignmentType = 'individual'
        } = req.body;

        const assignerId = req.userId;

        console.log('🔧 CREATE TASK DEBUG:');
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        console.log('Team ID received:', teamId);
        console.log('Assignment type:', assignmentType);

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ message: 'Task name is required' });
        }

        // PERMISSION CHECK: Verify team membership and permissions
        let team = null;
        if (teamId) {
            team = await Team.findById(teamId);
            if (!team) {
                return res.status(404).json({ message: 'Team not found' });
            }

            // Check if user can create tasks
            if (!canUserCreateTask(team, assignerId)) {
                return res.status(403).json({
                    message: 'Only team owners and admins can create tasks. Members can only complete tasks assigned to them.'
                });
            }
        }

        // Process assignees
        let assigneeIds = [];
        if (assignmentType === 'team' && teamId) {
            assigneeIds = team.members.map(member => member.user);
            console.log('Team assignment - assignees:', assigneeIds);
        } else if (assignedTo) {
            assigneeIds = Array.isArray(assignedTo) ? assignedTo : [assignedTo];
            console.log('Individual assignment - assignees:', assigneeIds);
        } else {
            assigneeIds = [assignerId];
            console.log('Self assignment - assignee:', assigneeIds);
        }

        // Validate assignees exist and are team members (if team task)
        if (teamId) {
            const teamMemberIds = team.members.map(m => m.user.toString());
            const invalidAssignees = assigneeIds.filter(id => !teamMemberIds.includes(id));

            if (invalidAssignees.length > 0) {
                return res.status(400).json({
                    message: 'Some assignees are not members of the team'
                });
            }
        }

        // Create task
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
            assignmentType
        });

        await task.save();

        // Populate task data for response
        await task.populate([
            { path: 'assignedTo', select: 'name email avatar' },
            { path: 'assignedBy', select: 'name email avatar' },
            { path: 'team', select: 'name' }
        ]);

        console.log('✅ Task created successfully:', task._id);

        // Send notifications to assignees (excluding self-assignment)
        const notificationRecipients = assigneeIds.filter(id => id !== assignerId);
        if (notificationRecipients.length > 0) {
            try {
                await sendTaskAssignedNotification(task, req.user, notificationRecipients);
            } catch (notifError) {
                console.error('Notification error (non-critical):', notifError);
            }
        }

        res.status(201).json({
            message: 'Task created successfully',
            task
        });
    } catch (err) {
        console.error('Create task error:', err);
        res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
        });
    }
};

// Update task - WITH PERMISSION CHECK
export const updateTask = async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const userId = req.userId;

        const task = await Task.findById(id).populate('team');
        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Get team for permission check
        let team = null;
        if (task.team) {
            team = await Team.findById(task.team._id);
        }

        // PERMISSION CHECK
        if (!canUserEditTask(task, team, userId)) {
            return res.status(403).json({
                message: 'You do not have permission to edit this task. Only task creators and team admins can edit tasks.'
            });
        }

        const updatedTask = await Task.findByIdAndUpdate(id, updates, { new: true })
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name');

        res.json({
            message: 'Task updated successfully',
            task: updatedTask
        });
    } catch (err) {
        console.error('Update task error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Complete task - MEMBERS CAN DO THIS
export const completeTask = async (req, res) => {
    try {
        const { id } = req.params;
        const { isCompleted } = req.body;
        const userId = req.userId;

        console.log(`🔧 COMPLETE TASK DEBUG: ${id}, isCompleted: ${isCompleted}, userId: ${userId}`);

        const task = await Task.findById(id)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar');

        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Check if user is assigned to this task
        const isAssignee = task.assignedTo.some(assignee =>
            assignee._id.toString() === userId
        );

        if (!isAssignee) {
            return res.status(403).json({
                message: 'You can only complete tasks assigned to you'
            });
        }

        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

        if (isCompleted) {
            const alreadyCompletedToday = task.completedDays.some(date => {
                const completedDate = new Date(date);
                const localDate = new Date(
                    completedDate.getFullYear(),
                    completedDate.getMonth(),
                    completedDate.getDate()
                );
                return localDate.getTime() === today.getTime();
            });

            if (!alreadyCompletedToday) {
                task.completedDays.push(today);
                task.lastCompletedDate = today;
                task.isArchived = true;
                task.archivedAt = new Date();

                const existingCompletion = task.completedBy.find(c =>
                    c.user.toString() === userId
                );

                if (!existingCompletion) {
                    task.completedBy.push({
                        user: userId,
                        completedAt: new Date()
                    });
                }
                console.log('✅ Task marked as completed');
            }
        } else {
            const beforeLength = task.completedDays.length;
            task.completedDays = task.completedDays.filter(date => {
                const completedDate = new Date(date);
                const localDate = new Date(
                    completedDate.getFullYear(),
                    completedDate.getMonth(),
                    completedDate.getDate()
                );
                return localDate.getTime() !== today.getTime();
            });

            task.completedBy = task.completedBy.filter(c => {
                const completionDate = new Date(c.completedAt);
                const completionDay = new Date(
                    completionDate.getFullYear(),
                    completionDate.getMonth(),
                    completionDate.getDate()
                );
                return !(c.user.toString() === userId && completionDay.getTime() === today.getTime());
            });

            const hasOtherCompletionsToday = task.completedBy.some(c => {
                const completionDate = new Date(c.completedAt);
                const completionDay = new Date(
                    completionDate.getFullYear(),
                    completionDate.getMonth(),
                    completionDate.getDate()
                );
                return completionDay.getTime() === today.getTime();
            });

            if (!hasOtherCompletionsToday) {
                task.isArchived = false;
                task.archivedAt = null;
            }

            if (task.completedDays.length > 0) {
                task.lastCompletedDate = task.completedDays.reduce((a, b) =>
                    new Date(a) > new Date(b) ? a : b
                );
            } else {
                task.lastCompletedDate = null;
            }
        }

        await task.save();

        if (isCompleted && task.assignedBy && task.assignedBy._id.toString() !== userId) {
            try {
                await sendTaskCompletedNotification(task, req.user, task.assignedBy._id);
            } catch (notifError) {
                console.error('Notification error (non-critical):', notifError);
            }
        }

        await task.populate([
            { path: 'completedBy.user', select: 'name email avatar' },
            { path: 'team', select: 'name' }
        ]);

        res.json({
            message: `Task ${isCompleted ? 'completed' : 'unmarked'} successfully`,
            task: task
        });
    } catch (err) {
        console.error('Complete task error:', err);
        res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
        });
    }
};

// Delete task - WITH PERMISSION CHECK
export const deleteTask = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.userId;

        const task = await Task.findById(id);
        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Get team for permission check
        let team = null;
        if (task.team) {
            team = await Team.findById(task.team);
        }

        // PERMISSION CHECK
        if (!canUserDeleteTask(task, team, userId)) {
            return res.status(403).json({
                message: 'You do not have permission to delete this task. Only task creators and team admins can delete tasks.'
            });
        }

        await saveTaskToHistory(task);
        await task.deleteOne();

        res.json({
            message: 'Task deleted successfully and preserved in history'
        });
    } catch (err) {
        console.error('Delete task error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get user tasks (existing code - no changes needed)
export const getUserTasks = async (req, res) => {
    try {
        const { userId, teamId, type = 'all' } = req.query;
        const requesterId = req.userId;

        let query = {};

        if (type === 'personal') {
            query = {
                assignedTo: userId || requesterId,
                team: { $exists: false }
            };
        } else if (type === 'team' && teamId) {
            query = {
                team: teamId,
                assignedTo: userId || requesterId
            };
        } else {
            query = {
                assignedTo: userId || requesterId
            };
        }

        const tasks = await Task.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name')
            .populate({
                path: 'completedBy.user',
                select: 'name email avatar'
            })
            .sort({ createdAt: -1 });

        const cleanedTasks = tasks.map(task => {
            const taskObj = task.toObject();
            if (taskObj.completedBy && taskObj.completedBy.length > 0) {
                taskObj.completedBy = taskObj.completedBy.map(completion => ({
                    user: completion.user || {
                        _id: 'unknown',
                        name: 'Unknown User',
                        email: '',
                        avatar: null
                    },
                    completedAt: completion.completedAt
                }));
            }
            return taskObj;
        });

        res.json(cleanedTasks);
    } catch (err) {
        console.error('Get user tasks error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get team tasks (existing code - no changes needed)
export const getTeamTasks = async (req, res) => {
    try {
        const { teamId } = req.params;
        const { status = 'active' } = req.query;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        const isMember = team.members.some(member =>
            member.user.toString() === userId
        );

        if (!isMember) {
            return res.status(403).json({ message: 'Access denied' });
        }

        let query = { team: teamId };

        if (status === 'active') {
            query.isArchived = false;
        } else if (status === 'archived') {
            query.isArchived = true;
        }

        const tasks = await Task.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate({
                path: 'completedBy.user',
                select: 'name email avatar'
            })
            .populate('team', 'name')
            .sort({ createdAt: -1 });

        const cleanedTasks = tasks.map(task => {
            const taskObj = task.toObject();
            if (taskObj.completedBy && taskObj.completedBy.length > 0) {
                taskObj.completedBy = taskObj.completedBy.map(completion => ({
                    user: completion.user || {
                        _id: 'unknown',
                        name: 'Unknown User',
                        email: '',
                        avatar: null
                    },
                    completedAt: completion.completedAt
                }));
            }
            return taskObj;
        });

        res.json(cleanedTasks);
    } catch (err) {
        console.error('Get team tasks error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Other existing functions remain unchanged
export const getTaskHistory = async (req, res) => {
    try {
        const { userId, teamId } = req.query;
        const requesterId = req.userId;

        let query = {};

        if (teamId) {
            const team = await Team.findById(teamId);
            if (!team) {
                return res.status(404).json({ message: 'Team not found' });
            }

            const isMember = team.members.some(member =>
                member.user.toString() === requesterId
            );

            if (!isMember) {
                return res.status(403).json({ message: 'Access denied' });
            }

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
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

export const getDashboardStats = async (req, res) => {
    try {
        const { teamId } = req.query;
        const userId = req.userId;

        let query = { assignedTo: userId };
        if (teamId) {
            query.team = teamId;
        }

        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const [
            totalTasks,
            completedToday,
            overdueTasks,
            upcomingTasks
        ] = await Promise.all([
            Task.countDocuments({ ...query, isArchived: false }),
            Task.countDocuments({
                ...query,
                completedDays: {
                    $elemMatch: {
                        $gte: today,
                        $lt: new Date(today.getTime() + 24 * 60 * 60 * 1000)
                    }
                }
            }),
            Task.countDocuments({
                ...query,
                dueDate: { $lt: today },
                isArchived: false
            }),
            Task.countDocuments({
                ...query,
                dueDate: {
                    $gte: today,
                    $lte: new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000)
                },
                isArchived: false
            })
        ]);

        res.json({
            totalTasks,
            completedToday,
            overdueTasks,
            upcomingTasks
        });
    } catch (err) {
        console.error('Get dashboard stats error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};