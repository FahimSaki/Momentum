import Task from '../models/Task.js';
import TaskHistory from '../models/TaskHistory.js';

// Helper function to save task to history before deletion
const saveTaskToHistory = async (task) => {
    if (task.completedDays?.length > 0) {
        try {
            // Check if this task's history already exists to avoid duplicates
            const existingHistory = await TaskHistory.findOne({
                userId: task.assignedTo,
                taskName: task.name
            });

            if (existingHistory) {
                // Merge completion days and remove duplicates
                const allDays = [...existingHistory.completedDays, ...task.completedDays];
                const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))].map(d => new Date(d));
                existingHistory.completedDays = uniqueDays;
                await existingHistory.save();
                console.log(`Updated existing history for "${task.name}" with ${task.completedDays.length} new completion days`);
            } else {
                // Create new history record
                await TaskHistory.create({
                    userId: task.assignedTo,
                    completedDays: task.completedDays,
                    taskName: task.name
                });
                console.log(`Saved task "${task.name}" to history with ${task.completedDays.length} completion days`);
            }
        } catch (error) {
            console.error(`Error saving task "${task.name}" to history:`, error);
        }
    }
};

// ✅ Create a new task
export const createTask = async (req, res) => {
    try {
        const { name, userId } = req.body;
        if (!name || !userId) {
            return res.status(400).json({ message: 'Name and userId are required' });
        }
        const task = new Task({ name, assignedTo: userId });
        await task.save();
        res.status(200).json(task);
    } catch (err) {
        res.status(500).json({ message: 'Error creating task', error: err.message });
    }
};

// ✅ Get all tasks for a user
export const getAssignedTasks = async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });
        const tasks = await Task.find({ assignedTo: userId });
        res.status(200).json(tasks);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching tasks', error: err.message });
    }
};

// ✅ Update a task
export const updateTask = async (req, res) => {
    try {
        const { id } = req.params;
        const update = req.body;
        const task = await Task.findByIdAndUpdate(id, update, { new: true });
        if (!task) return res.status(404).json({ message: 'Task not found' });
        res.status(200).json(task);
    } catch (err) {
        res.status(500).json({ message: 'Error updating task', error: err.message });
    }
};

// 🔧 UPDATED: Archive tasks completed before today (date-based, not time-based)
export const archiveCompletedTasks = async (req, res) => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Archive tasks that were completed before today (yesterday or earlier)
        const result = await Task.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        res.status(200).json({
            message: `${result.modifiedCount} tasks archived (completed before ${today.toDateString()})`
        });
    } catch (err) {
        res.status(500).json({ message: 'Error archiving tasks', error: err.message });
    }
};

// 🔧 UPDATED: Delete completed tasks (date-based logic)
export const deleteCompletedTasks = async (req, res) => {
    try {
        const { userId, before } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });

        // Parse the before date or use today as default
        let beforeDate;
        if (before) {
            beforeDate = new Date(before);
            beforeDate.setUTCHours(0, 0, 0, 0); // Set to start of the specified day
        } else {
            // Default: delete tasks archived before today (i.e., yesterday and earlier)
            beforeDate = new Date();
            beforeDate.setUTCHours(0, 0, 0, 0);
        }

        console.log(`Deleting completed tasks for user ${userId} archived before ${beforeDate.toDateString()}`);

        // Find tasks to delete (archived before the specified date)
        const tasksToDelete = await Task.find({
            assignedTo: userId,
            isArchived: true,
            archivedAt: { $lt: beforeDate }
        });

        console.log(`Found ${tasksToDelete.length} tasks to delete and preserve`);

        // Save each task to history before deletion
        for (const task of tasksToDelete) {
            await saveTaskToHistory(task);
            await task.deleteOne();
        }

        res.status(200).json({
            message: `${tasksToDelete.length} completed tasks deleted and preserved in history`
        });
    } catch (err) {
        console.error('Error in deleteCompletedTasks:', err);
        res.status(500).json({ message: 'Error deleting completed tasks', error: err.message });
    }
};

// 🔧 UPDATED: Delete old archived tasks (date-based)
export const deleteOldArchivedTasks = async (req, res) => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Find tasks that were archived before today
        const tasksToDelete = await Task.find({
            isArchived: true,
            archivedAt: { $lt: today }
        });

        console.log(`Found ${tasksToDelete.length} old archived tasks to delete (archived before ${today.toDateString()})`);

        for (const task of tasksToDelete) {
            await saveTaskToHistory(task);
            await task.deleteOne();
        }

        res.status(200).json({
            message: `${tasksToDelete.length} old archived tasks deleted and history preserved`
        });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting old archived tasks', error: err.message });
    }
};

// 🔧 UPDATED: Remove old completion days (date-based)
export const removeOldCompletionDays = async (req, res) => {
    try {
        const { userId, before } = req.body;

        // If no specific date provided, use today as cutoff
        let beforeDate;
        if (before) {
            beforeDate = new Date(before);
            beforeDate.setUTCHours(0, 0, 0, 0);
        } else {
            beforeDate = new Date();
            beforeDate.setUTCHours(0, 0, 0, 0);
        }

        const query = userId ? { assignedTo: userId } : {};
        const tasks = await Task.find(query);

        for (const task of tasks) {
            // Save to history BEFORE removing completion days
            const oldCompletions = task.completedDays.filter(date => new Date(date) < beforeDate);

            if (oldCompletions.length > 0) {
                const taskWithOldData = {
                    ...task.toObject(),
                    completedDays: oldCompletions
                };
                await saveTaskToHistory(taskWithOldData);
            }

            // Remove old completion days (keep only today and future)
            task.completedDays = task.completedDays.filter(date => new Date(date) >= beforeDate);
            await task.save();
        }

        res.status(200).json({
            message: `Old completion days removed and preserved in history (before ${beforeDate.toDateString()})`
        });
    } catch (err) {
        res.status(500).json({ message: 'Error removing old completion days', error: err.message });
    }
};

// 🔧 UPDATED: Remove only yesterday's completions but SAVE TO HISTORY FIRST (date-based)
export const removeYesterdayCompletions = async (req, res) => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const tasks = await Task.find({});
        let savedCount = 0;

        for (const task of tasks) {
            // Get completions from before today (yesterday and earlier)
            const oldCompletions = task.completedDays.filter(date => new Date(date) < today);

            if (oldCompletions.length > 0) {
                // Create a temporary task object with only old completions
                const taskWithOldData = {
                    ...task.toObject(),
                    completedDays: oldCompletions
                };

                await saveTaskToHistory(taskWithOldData);
                savedCount++;
            }

            // Now remove old completions (keep only today's completions)
            task.completedDays = task.completedDays.filter(date => new Date(date) >= today);
            await task.save();
        }

        console.log(`Saved ${savedCount} tasks to history before removing old completions`);
        res.status(200).json({
            message: `Old completions removed and ${savedCount} tasks preserved in history (before ${today.toDateString()})`
        });
    } catch (err) {
        console.error('Error in removeYesterdayCompletions:', err);
        res.status(500).json({ message: 'Error removing old completions', error: err.message });
    }
};

// ✅ Manual deletion by task ID - FIXED to preserve history
export const deleteTask = async (req, res) => {
    try {
        const { id } = req.params;
        const task = await Task.findById(id);
        if (!task) return res.status(404).json({ message: 'Task not found' });

        // Save to history before manual deletion
        await saveTaskToHistory(task);

        await task.deleteOne();
        res.status(200).json({ message: 'Task deleted successfully and preserved in history' });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting task', error: err.message });
    }
};

// ✅ Get task history for heatmap
export const getTaskHistory = async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });

        const history = await TaskHistory.find({ userId });
        console.log(`Retrieved ${history.length} task history records for user ${userId}`);
        res.status(200).json(history);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching task history', error: err.message });
    }
};