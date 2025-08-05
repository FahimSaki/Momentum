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

// ✅ Archive habits completed before yesterday (UTC)
export const archiveCompletedHabits = async (req, res) => {
    try {
        const cutoff = new Date();
        cutoff.setUTCDate(cutoff.getUTCDate() - 1);
        cutoff.setUTCHours(0, 0, 0, 0);

        const result = await Habit.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: cutoff } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        res.status(200).json({ message: `${result.modifiedCount} habits archived` });
    } catch (err) {
        res.status(500).json({ message: 'Error archiving habits', error: err.message });
    }
};

// ✅ Delete completed habits (what your Flutter app actually calls)
export const deleteCompletedHabits = async (req, res) => {
    try {
        const { userId, before } = req.query;
        if (!userId) return res.status(400).json({ message: 'userId is required' });

        // Parse the before date or use yesterday as default
        let beforeDate;
        if (before) {
            beforeDate = new Date(before);
        } else {
            beforeDate = new Date();
            beforeDate.setUTCDate(beforeDate.getUTCDate() - 1);
            beforeDate.setUTCHours(0, 0, 0, 0);
        }

        console.log(`Deleting completed habits for user ${userId} before ${beforeDate.toISOString()}`);

        // Find habits to delete
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

// ✅ Delete old archived habits and preserve heatmap data (UTC)
export const deleteOldArchivedHabits = async (req, res) => {
    try {
        const cutoff = new Date();
        cutoff.setUTCDate(cutoff.getUTCDate() - 1);
        cutoff.setUTCHours(0, 0, 0, 0);

        const habitsToDelete = await Habit.find({
            isArchived: true,
            archivedAt: { $lt: cutoff }
        });

        console.log(`Found ${habitsToDelete.length} old archived habits to delete`);

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

// ✅ Remove old completion days (based on UTC date)
export const removeOldCompletionDays = async (req, res) => {
    try {
        const { userId, before } = req.body;
        if (!userId || !before) return res.status(400).json({ message: 'userId and before date are required' });

        const beforeDate = new Date(before); // Assume this is an ISO date in UTC

        const habits = await Habit.find({ assignedTo: userId });

        for (const habit of habits) {
            // Save to history BEFORE removing completion days
            await saveHabitToHistory(habit);

            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= beforeDate);
            await habit.save();
        }

        res.status(200).json({ message: 'Old completion days removed and preserved in history' });
    } catch (err) {
        res.status(500).json({ message: 'Error removing old completion days', error: err.message });
    }
};

// 🔧 FIXED: Remove only yesterday's completions but SAVE TO HISTORY FIRST
export const removeYesterdayCompletions = async (req, res) => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0); // Midnight UTC

        const habits = await Habit.find({});
        let savedCount = 0;

        for (const habit of habits) {
            // 🔧 CRITICAL FIX: Save to history BEFORE removing completion days
            const yesterdayCompletions = habit.completedDays.filter(date => new Date(date) < today);

            if (yesterdayCompletions.length > 0) {
                // Create a temporary habit object with only yesterday's completions
                const habitWithYesterdayData = {
                    ...habit.toObject(),
                    completedDays: yesterdayCompletions
                };

                await saveHabitToHistory(habitWithYesterdayData);
                savedCount++;
            }

            // Now remove yesterday's completions
            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= today);
            await habit.save();
        }

        console.log(`Saved ${savedCount} habits to history before removing yesterday's completions`);
        res.status(200).json({
            message: `Yesterday completions removed and ${savedCount} habits preserved in history`
        });
    } catch (err) {
        console.error('Error in removeYesterdayCompletions:', err);
        res.status(500).json({ message: 'Error removing yesterday completions', error: err.message });
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