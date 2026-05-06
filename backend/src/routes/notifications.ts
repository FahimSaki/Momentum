import { Router } from 'express';
import {
    getNotifications,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    getUnreadCount,
} from '../controllers/notificationController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.use(authenticateToken);

router.get('/', getNotifications);
router.get('/unread-count', getUnreadCount);
router.patch('/:notificationId/read', markAsRead);
router.patch('/mark-all-read', markAllAsRead);
router.delete('/:notificationId', deleteNotification);

export default router;