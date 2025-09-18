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

// FIX: Make sure all routes are properly defined
router.post('/', createTask);                    // POST /tasks
router.get('/user', getUserTasks);               // GET /tasks/user  
router.get('/assigned', getUserTasks);           // GET /tasks/assigned (alias)
router.get('/history', getTaskHistory);          // GET /tasks/history
router.get('/stats', getDashboardStats);         // GET /tasks/stats
router.get('/team/:teamId', getTeamTasks);       // GET /tasks/team/:teamId
router.put('/:id', updateTask);                  // PUT /tasks/:id
router.put('/:id/complete', completeTask);       // PUT /tasks/:id/complete
router.delete('/:id', deleteTask);               // DELETE /tasks/:id

export default router;