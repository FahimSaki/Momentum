
import Task from '../models/Task.js';
import TaskHistory from '../models/TaskHistory.js';
import Team from '../models/Team.js';
import User from '../models/User.js';
import { sendTaskAssignedNotification, sendTaskCompletedNotification } from '../services/notificationService.js';

// Helper function to save task to history before deletion (enhanced)
const saveTaskToHistory = async (task) => {
    if (task.completedDays?.length > 0) {
        try {
            // For team tasks, save history for each assignee
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
                        teamId: task.team // Add team reference to history
                    });
                }
            }

            console.log(`Saved task "${task.name}" to history for ${assigneeIds.length} users`);
        } catch (error) {
            console.error(`Error saving task "${task.name}" to history:`, error);
        }
    }
};

// Create a new task (enhanced for teams)
export const createTask = async (req, res) => {
    try {
        const {
            name,
            description,
            assignedTo, // Can be array or single userId
            teamId,
            priority = 'medium',
            dueDate,
            tags = [],
            assignmentType = 'individual'
        } = req.body;

        const assignerId = req.userId;

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ message: 'Task name is required' });
        }

        // Validate team membership if teamId is provided
        if (teamId) {
            const team = await Team.findById(teamId);
            if (!team) {
                return res.status(404).json({ message: 'Team not found' });
            }

            const isMember = team.members.some(member =>
                member.user.toString() === assignerId
            );

            if (!isMember) {
                return res.status(403).json({ message: 'You are not a member of this team' });
            }
        }

        // Process assignees
        let assigneeIds = [];
        if (assignmentType === 'team' && teamId) {
            // Assign to all team members
            const team = await Team.findById(teamId);
            assigneeIds = team.members.map(member => member.user);
        } else if (assignedTo) {
            assigneeIds = Array.isArray(assignedTo) ? assignedTo : [assignedTo];
        } else {
            // Self-assignment if no assignee specified
            assigneeIds = [assignerId];
        }

        // Validate assignees exist and are team members (if team task)
        if (teamId) {
            const team = await Team.findById(teamId);
            const teamMemberIds = team.members.map(m => m.user.toString());
            const invalidAssignees = assigneeIds.filter(id => !teamMemberIds.includes(id));

            if (invalidAssignees.length > 0) {
                return res.status(400).json({
                    message: 'Some assignees are not members of the team'
                });
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
            assignmentType
        });

        await task.save();

        // Populate task data for response
        await task.populate([
            { path: 'assignedTo', select: 'name email avatar' },
            { path: 'assignedBy', select: 'name email avatar' },
            { path: 'team', select: 'name' }
        ]);

        // Send notifications to assignees (excluding self-assignment)
        const notificationRecipients = assigneeIds.filter(id => id !== assignerId);
        if (notificationRecipients.length > 0) {
            await sendTaskAssignedNotification(task, req.user, notificationRecipients);
        }

        res.status(201).json({
            message: 'Task created successfully',
            task
        });
    } catch (err) {
        console.error('Create task error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get tasks for user (enhanced with team tasks)
export const getUserTasks = async (req, res) => {
    try {
        const { userId, teamId, type = 'all' } = req.query;
        const requesterId = req.userId;

        // Build query
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
            // All tasks assigned to user (personal + team)
            query = {
                assignedTo: userId || requesterId
            };
        }

        const tasks = await Task.find(query)
            .populate('assignedTo', 'name email avatar')
            .populate('assignedBy', 'name email avatar')
            .populate('team', 'name')
            .sort({ createdAt: -1 });

        res.json(tasks);
    } catch (err) {
        console.error('Get user tasks error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get team tasks
export const getTeamTasks = async (req, res) => {
    try {
        const { teamId } = req.params;
        const { status = 'active' } = req.query;
        const userId = req.userId;

        // Verify team membership
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
            .populate('completedBy.user', 'name email avatar')
            .sort({ createdAt: -1 });

        res.json(tasks);
    } catch (err) {
        console.error('Get team tasks error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Update task (enhanced)
export const updateTask = async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const userId = req.userId;

        const task = await Task.findById(id)
            .populate('team');

        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Check permissions
        const isAssignee = task.assignedTo.some(assigneeId =>
            assigneeId.toString() === userId
        );
        const isAssigner = task.assignedBy?.toString() === userId;
        let isTeamMember = false;

        if (task.team) {
            const team = await Team.findById(task.team._id);
            isTeamMember = team.members.some(member =>
                member.user.toString() === userId
            );
        }

        if (!isAssignee && !isAssigner && !isTeamMember) {
            return res.status(403).json({ message: 'Access denied' });
        }

        // Restrict certain updates to assigners only
        const restrictedFields = ['assignedTo', 'assignedBy', 'team', 'dueDate', 'priority'];
        const hasRestrictedUpdates = Object.keys(updates).some(key =>
            restrictedFields.includes(key)
        );

        if (hasRestrictedUpdates && !isAssigner && !isTeamMember) {
            return res.status(403).json({
                message: 'Only task assigners can modify assignment details'
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

// Complete task (enhanced for team tasks)
export const completeTask = async (req, res) => {
    try {
        const { id } = req.params;
        const { isCompleted } = req.body;
        const userId = req.userId;

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

        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        if (isCompleted) {
            // Add completion
            const alreadyCompletedToday = task.completedDays.some(date => {
                const completedDate = new Date(date);
                completedDate.setUTCHours(0, 0, 0, 0);
                return completedDate.getTime() === today.getTime();
            });

            if (!alreadyCompletedToday) {
                task.completedDays.push(today);
                task.lastCompletedDate = today;
                task.isArchived = true;
                task.archivedAt = new Date();

                // Track who completed it
                const existingCompletion = task.completedBy.find(c =>
                    c.user.toString() === userId
                );

                if (!existingCompletion) {
                    task.completedBy.push({
                        user: userId,
                        completedAt: new Date()
                    });
                }
            }
        } else {
            // Remove completion
            task.completedDays = task.completedDays.filter(date => {
                const completedDate = new Date(date);
                completedDate.setUTCHours(0, 0, 0, 0);
                return completedDate.getTime() !== today.getTime();
            });

            // Remove from completedBy
            task.completedBy = task.completedBy.filter(c =>
                c.user.toString() !== userId
            );

            // Update archive status
            const hasCompletionsToday = task.completedDays.some(date => {
                const completedDate = new Date(date);
                completedDate.setUTCHours(0, 0, 0, 0);
                return completedDate.getTime() === today.getTime();
            });

            if (!hasCompletionsToday) {
                task.isArchived = false;
                task.archivedAt = null;
            }

            if (task.completedDays.length > 0) {
                task.lastCompletedDate = task.completedDays.reduce((a, b) =>
                    a > b ? a : b
                );
            } else {
                task.lastCompletedDate = null;
            }
        }

        await task.save();

        // Send notification to assigner if task was completed
        if (isCompleted && task.assignedBy && task.assignedBy._id.toString() !== userId) {
            await sendTaskCompletedNotification(task, req.user, task.assignedBy._id);
        }

        await task.populate('team', 'name');

        res.json({
            message: `Task ${isCompleted ? 'completed' : 'unmarked'} successfully`,
            task
        });
    } catch (err) {
        console.error('Complete task error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Delete task (enhanced with permissions)
export const deleteTask = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.userId;

        const task = await Task.findById(id);
        if (!task) {
            return res.status(404).json({ message: 'Task not found' });
        }

        // Check permissions - only assigners and team admins/owners can delete
        let canDelete = false;

        if (task.assignedBy?.toString() === userId) {
            canDelete = true;
        } else if (task.team) {
            const team = await Team.findById(task.team);
            const member = team.members.find(m => m.user.toString() === userId);
            canDelete = member && ['owner', 'admin'].includes(member.role);
        }

        if (!canDelete) {
            return res.status(403).json({
                message: 'Only task assigners or team admins can delete tasks'
            });
        }

        // Save to history before deletion
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

// Get task history (enhanced with team support)
export const getTaskHistory = async (req, res) => {
    try {
        const { userId, teamId } = req.query;
        const requesterId = req.userId;

        let query = {};

        if (teamId) {
            // Verify team membership
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

// Get dashboard stats (new endpoint)
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