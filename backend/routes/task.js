import express from 'express';
import {
    createTask,
    getUserTasks,
    getTeamTasks,
    updateTask,
    completeTask,
    deleteTask,
    getTaskHistory,
    getDashboardStats
} from '../controllers/taskController.js';

const router = express.Router();

// Task CRUD
router.post('/', createTask);
router.get('/user', getUserTasks);
router.get('/team/:teamId', getTeamTasks);
router.put('/:id', updateTask);
router.put('/:id/complete', completeTask);
router.delete('/:id', deleteTask);

// Task history and analytics
router.get('/history', getTaskHistory);
router.get('/stats', getDashboardStats);

export default router;