import { Request, Response } from 'express';
import Task from '../models/Task';
import User from '../models/User';
import { AuthRequest } from '../middleware/authMiddleware';

export const createTask = async (req: AuthRequest, res: Response) => {
    try {
        const { title, description, assignedTo } = req.body;
        if (!title || !assignedTo) {
            return res.status(400).json({ message: 'Title and assignedTo are required.' });
        }
        const task = new Task({
            title,
            description,
            assignedTo,
            createdBy: req.user.userId,
        });
        await task.save();
        return res.status(201).json(task);
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};

export const getTasks = async (req: AuthRequest, res: Response) => {
    try {
        // Get tasks created by or assigned to the user
        const userId = req.user.userId;
        const tasks = await Task.find({ $or: [{ createdBy: userId }, { assignedTo: userId }] })
            .populate('assignedTo', 'email')
            .populate('createdBy', 'email');
        return res.status(200).json(tasks);
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};

export const getTaskById = async (req: AuthRequest, res: Response) => {
    try {
        const task = await Task.findById(req.params.id)
            .populate('assignedTo', 'email')
            .populate('createdBy', 'email');
        if (!task) return res.status(404).json({ message: 'Task not found.' });
        return res.status(200).json(task);
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};

export const updateTask = async (req: AuthRequest, res: Response) => {
    try {
        const { title, description, status, assignedTo } = req.body;
        const task = await Task.findById(req.params.id);
        if (!task) return res.status(404).json({ message: 'Task not found.' });
        if (title) task.title = title;
        if (description) task.description = description;
        if (status) task.status = status;
        if (assignedTo) task.assignedTo = assignedTo;
        await task.save();
        return res.status(200).json(task);
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};

export const deleteTask = async (req: AuthRequest, res: Response) => {
    try {
        const task = await Task.findByIdAndDelete(req.params.id);
        if (!task) return res.status(404).json({ message: 'Task not found.' });
        return res.status(200).json({ message: 'Task deleted.' });
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};

export const assignTask = async (req: AuthRequest, res: Response) => {
    try {
        const { assignedTo } = req.body;
        const task = await Task.findById(req.params.id);
        if (!task) return res.status(404).json({ message: 'Task not found.' });
        const user = await User.findById(assignedTo);
        if (!user) return res.status(404).json({ message: 'User to assign not found.' });
        task.assignedTo = assignedTo;
        await task.save();
        return res.status(200).json(task);
    } catch (err) {
        return res.status(500).json({ message: 'Server error.' });
    }
};
