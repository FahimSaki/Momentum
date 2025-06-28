import express from 'express';
import {
    createTask,
    getTasks,
    updateTask,
    deleteTask,
    assignTask,
    getTaskById
} from '../controllers/taskController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = express.Router();

// All routes require authentication
router.use(authMiddleware);

router.post('/', createTask);
router.get('/', getTasks);
router.get('/:id', getTaskById);
router.put('/:id', updateTask);
router.delete('/:id', deleteTask);
router.post('/:id/assign', assignTask);

export default router;
