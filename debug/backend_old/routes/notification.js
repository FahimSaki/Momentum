import express from 'express';
import {
    getNotifications,
    markAsRead,
    markAllAsRead,
    updateToken
} from '../controllers/notificationController.js';

const router = express.Router();

// Get user notifications
router.get('/', getNotifications);

// Mark notification as read
router.put('/:notificationId/read', markAsRead);

// Mark all notifications as read
router.put('/read-all', markAllAsRead);

// Update FCM token
router.post('/fcm-token', updateToken);

export default router;