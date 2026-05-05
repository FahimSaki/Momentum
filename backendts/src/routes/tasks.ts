import { Router } from 'express';
import {
    createTask,
    updateTask,
    completeTask,
    deleteTask,
    getUserTasks,
    getTeamTasks,
    getTaskHistory,
    getDashboardStats,
} from '../controllers/taskController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.use(authenticateToken);

router.post('/', createTask);
router.get('/', getUserTasks);
router.get('/history', getTaskHistory);
router.get('/dashboard-stats', getDashboardStats);
router.get('/team/:teamId', getTeamTasks);
router.put('/:id', updateTask);
router.patch('/:id/complete', completeTask);
router.delete('/:id', deleteTask);

export default router;