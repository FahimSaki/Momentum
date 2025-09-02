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

// ADD MISSING ROUTES THAT YOUR FRONTEND IS CALLING
router.get('/assigned', getUserTasks); // Alias for /user route
router.get('/history', getTaskHistory); // Move this up
router.get('/stats', getDashboardStats); // Move this up

router.get('/team/:teamId', getTeamTasks);
router.put('/:id', updateTask);
router.put('/:id/complete', completeTask);
router.delete('/:id', deleteTask);

export default router;
