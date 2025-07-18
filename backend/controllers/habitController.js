// Update a habit
export const updateHabit = async (req, res) => {
    try {
        const { id } = req.params;
        const update = req.body;
        const habit = await Habit.findByIdAndUpdate(id, update, { new: true });
        if (!habit) {
            return res.status(404).json({ message: 'Habit not found' });
        }
        res.status(200).json(habit);
    } catch (err) {
        res.status(500).json({ message: 'Error updating habit', error: err.message });
    }
};

// Delete a habit
export const deleteHabit = async (req, res) => {
    try {
        const { id } = req.params;
        const habit = await Habit.findByIdAndDelete(id);
        if (!habit) {
            return res.status(404).json({ message: 'Habit not found' });
        }
        res.status(200).json({ message: 'Habit deleted' });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting habit', error: err.message });
    }
};
import Habit from '../models/Habit.js';

// TODO: Implement habit CRUD and assignment logic

// Create a new habit
export const createHabit = async (req, res) => {
    try {
        const { name, userId } = req.body;
        if (!name || !userId) {
            return res.status(400).json({ message: 'Name and userId are required' });
        }
        const habit = new Habit({
            name,
            assignedTo: userId
        });
        await habit.save();
        res.status(200).json(habit);
    } catch (err) {
        res.status(500).json({ message: 'Error creating habit', error: err.message });
    }
};


// Get all habits assigned to a user
export const getAssignedHabits = async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) {
            return res.status(400).json({ message: 'userId is required' });
        }
        const habits = await Habit.find({ assignedTo: userId });
        res.status(200).json(habits);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching habits', error: err.message });
    }
};


// Remove old completion days from all habits for a user
export const removeOldCompletionDays = async (req, res) => {
    try {
        const { userId, before } = req.body;
        if (!userId || !before) {
            return res.status(400).json({ message: 'userId and before date are required' });
        }
        const beforeDate = new Date(before);
        const habits = await Habit.find({ assignedTo: userId });
        for (const habit of habits) {
            habit.completedDays = habit.completedDays.filter(date => date >= beforeDate);
            await habit.save();
        }
        res.status(200).json({ message: 'Old completion days removed' });
    } catch (err) {
        res.status(500).json({ message: 'Error removing old completion days', error: err.message });
    }
};

// Remove completion days older than today for all users (for scheduled job or midnight trigger)
export const removeYesterdayCompletions = async (req, res) => {
    try {
        const today = new Date();
        today.setHours(0, 0, 0, 0); // Midnight today
        const habits = await Habit.find({});
        for (const habit of habits) {
            habit.completedDays = habit.completedDays.filter(date => {
                const d = new Date(date);
                return d >= today;
            });
            await habit.save();
        }
        res.status(200).json({ message: 'Yesterday completions removed from all habits' });
    } catch (err) {
        res.status(500).json({ message: 'Error removing yesterday completions', error: err.message });
    }
};
