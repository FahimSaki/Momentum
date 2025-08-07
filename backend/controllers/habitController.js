import Habit from '../models/Habit.js';
import HabitHistory from '../models/HabitHistory.js';

// Helper function to save habit to history before deletion
const saveHabitToHistory = async (habit) => {
    if (habit.completedDays?.length > 0) {
        try {
            // Check if this habit's history already exists to avoid duplicates
            const existingHistory = await HabitHistory.findOne({
                userId: habit.assignedTo,
                habitName: habit.name
            });

            if (existingHistory) {
                // Merge completion days and remove duplicates
                const allDays = [...existingHistory.completedDays, ...habit.completedDays];
                const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))].map(d => new Date(d));
                existingHistory.completedDays = uniqueDays;
                await existingHistory.save();
                console.log(`Updated existing history for "${habit.name}" with ${habit.completedDays.length} new completion days`);
            } else {
                // Create new history record
                await HabitHistory.create({
                    userId: habit.assignedTo,
                    completedDays: habit.completedDays,
                    habitName: habit.name
                });
                console.log(`Saved habit "${habit.name}" to history with ${habit.completedDays.length} completion days`);
            }
        } catch (error) {
            console.error(`Error saving habit "${habit.name}" to history:`, error);
        }
    }
};

// ✅ Create a new habit
export const createHabit = async (req, res) => {
    try {
        const { name, userId } = req.body;
        if (!name || !userId) {
            return res.status(400).json({ message: 'Name and userId are required' });
        }
        const habit = new Habit({ name, assignedTo: userId });
        await habit.save();
        res.status(200).json(habit);
    } catch (err) {
        res.status(500).json({ message: 'Error creating habit', error: err.message });
    }
};

// ✅ Get all habits for a user
export const getAssignedHabits = async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });
        const habits = await Habit.find({ assignedTo: userId });
        res.status(200).json(habits);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching habits', error: err.message });
    }
};

// ✅ Update a habit
export const updateHabit = async (req, res) => {
    try {
        const { id } = req.params;
        const update = req.body;
        const habit = await Habit.findByIdAndUpdate(id, update, { new: true });
        if (!habit) return res.status(404).json({ message: 'Habit not found' });
        res.status(200).json(habit);
    } catch (err) {
        res.status(500).json({ message: 'Error updating habit', error: err.message });
    }
};

// 🔧 UPDATED: Archive habits completed before today (date-based, not time-based)
export const archiveCompletedHabits = async (req, res) => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Archive habits that were completed before today (yesterday or earlier)
        const result = await Habit.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        res.status(200).json({
            message: `${result.modifiedCount} habits archived (completed before ${today.toDateString()})`
        });
    } catch (err) {
        res.status(500).json({ message: 'Error archiving habits', error: err.message });
    }
};

// 🔧 UPDATED: Delete completed habits (date-based logic)
export const deleteCompletedHabits = async (req, res) => {
    try {
        const { userId, before } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });

        // Parse the before date or use today as default
        let beforeDate;
        if (before) {
            beforeDate = new Date(before);
            beforeDate.setUTCHours(0, 0, 0, 0); // Set to start of the specified day
        } else {
            // Default: delete habits archived before today (i.e., yesterday and earlier)
            beforeDate = new Date();
            beforeDate.setUTCHours(0, 0, 0, 0);
        }

        console.log(`Deleting completed habits for user ${userId} archived before ${beforeDate.toDateString()}`);

        // Find habits to delete (archived before the specified date)
        const habitsToDelete = await Habit.find({
            assignedTo: userId,
            isArchived: true,
            archivedAt: { $lt: beforeDate }
        });

        console.log(`Found ${habitsToDelete.length} habits to delete and preserve`);

        // Save each habit to history before deletion
        for (const habit of habitsToDelete) {
            await saveHabitToHistory(habit);
            await habit.deleteOne();
        }

        res.status(200).json({
            message: `${habitsToDelete.length} completed habits deleted and preserved in history`
        });
    } catch (err) {
        console.error('Error in deleteCompletedHabits:', err);
        res.status(500).json({ message: 'Error deleting completed habits', error: err.message });
    }
};

// 🔧 UPDATED: Delete old archived habits (date-based)
export const deleteOldArchivedHabits = async (req, res) => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Find habits that were archived before today
        const habitsToDelete = await Habit.find({
            isArchived: true,
            archivedAt: { $lt: today }
        });

        console.log(`Found ${habitsToDelete.length} old archived habits to delete (archived before ${today.toDateString()})`);

        for (const habit of habitsToDelete) {
            await saveHabitToHistory(habit);
            await habit.deleteOne();
        }

        res.status(200).json({
            message: `${habitsToDelete.length} old archived habits deleted and history preserved`
        });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting old archived habits', error: err.message });
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
        const habits = await Habit.find(query);

        for (const habit of habits) {
            // Save to history BEFORE removing completion days
            const oldCompletions = habit.completedDays.filter(date => new Date(date) < beforeDate);

            if (oldCompletions.length > 0) {
                const habitWithOldData = {
                    ...habit.toObject(),
                    completedDays: oldCompletions
                };
                await saveHabitToHistory(habitWithOldData);
            }

            // Remove old completion days (keep only today and future)
            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= beforeDate);
            await habit.save();
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

        const habits = await Habit.find({});
        let savedCount = 0;

        for (const habit of habits) {
            // Get completions from before today (yesterday and earlier)
            const oldCompletions = habit.completedDays.filter(date => new Date(date) < today);

            if (oldCompletions.length > 0) {
                // Create a temporary habit object with only old completions
                const habitWithOldData = {
                    ...habit.toObject(),
                    completedDays: oldCompletions
                };

                await saveHabitToHistory(habitWithOldData);
                savedCount++;
            }

            // Now remove old completions (keep only today's completions)
            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= today);
            await habit.save();
        }

        console.log(`Saved ${savedCount} habits to history before removing old completions`);
        res.status(200).json({
            message: `Old completions removed and ${savedCount} habits preserved in history (before ${today.toDateString()})`
        });
    } catch (err) {
        console.error('Error in removeYesterdayCompletions:', err);
        res.status(500).json({ message: 'Error removing old completions', error: err.message });
    }
};

// ✅ Manual deletion by habit ID - FIXED to preserve history
export const deleteHabit = async (req, res) => {
    try {
        const { id } = req.params;
        const habit = await Habit.findById(id);
        if (!habit) return res.status(404).json({ message: 'Habit not found' });

        // Save to history before manual deletion
        await saveHabitToHistory(habit);

        await habit.deleteOne();
        res.status(200).json({ message: 'Habit deleted successfully and preserved in history' });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting habit', error: err.message });
    }
};

// ✅ Get habit history for heatmap
export const getHabitHistory = async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });

        const history = await HabitHistory.find({ userId });
        console.log(`Retrieved ${history.length} habit history records for user ${userId}`);
        res.status(200).json(history);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching habit history', error: err.message });
    }
};