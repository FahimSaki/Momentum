import Habit from '../models/Habit.js';

// TODO: Implement habit CRUD and assignment logic

// Create a new habit
export const createHabit = async (req, res) => {
    try {
        const { name, userId, device_id } = req.body;
        if (!name || !userId) {
            return res.status(400).json({ message: 'Name and userId are required' });
        }
        const habit = new Habit({
            name,
            assignedTo: userId,
            // Optionally store device_id or other fields if needed
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
