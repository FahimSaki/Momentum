import Habit from '../models/Habit.js';
import HabitHistory from '../models/HabitHistory.js';

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

        for (const habit of habitsToDelete) {
            if (habit.completedDays?.length > 0) {
                await HabitHistory.create({
                    userId: habit.assignedTo,
                    completedDays: habit.completedDays,
                    habitName: habit.name
                });
            }

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
            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= beforeDate);
            await habit.save();
        }

        res.status(200).json({ message: 'Old completion days removed' });
    } catch (err) {
        res.status(500).json({ message: 'Error removing old completion days', error: err.message });
    }
};

// ✅ Remove only yesterday’s completions (UTC)
export const removeYesterdayCompletions = async (req, res) => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0); // Midnight UTC

        const habits = await Habit.find({});

        for (const habit of habits) {
            habit.completedDays = habit.completedDays.filter(date => new Date(date) >= today);
            await habit.save();
        }

        res.status(200).json({ message: 'Yesterday completions removed' });
    } catch (err) {
        res.status(500).json({ message: 'Error removing yesterday completions', error: err.message });
    }
};

// ✅ Manual deletion by habit ID
export const deleteHabit = async (req, res) => {
    try {
        const { id } = req.params;
        const habit = await Habit.findByIdAndDelete(id);
        if (!habit) return res.status(404).json({ message: 'Habit not found' });
        res.status(200).json({ message: 'Habit deleted successfully' });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting habit', error: err.message });
    }
};
