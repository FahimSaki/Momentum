// backend/controllers/notificationController.js - FIXED VERSION

import {
    getUserNotifications,
    markNotificationAsRead,
    markAllNotificationsAsRead,
    updateFCMToken
} from '../services/notificationService.js';

// Get user notifications - FIXED RESPONSE FORMAT
export const getNotifications = async (req, res) => {
    try {
        const userId = req.userId;
        const {
            limit = 50,
            offset = 0,
            unreadOnly = false
        } = req.query;

        console.log(`📬 Getting notifications for user: ${userId}`);

        const result = await getUserNotifications(
            userId,
            parseInt(limit),
            parseInt(offset),
            unreadOnly === 'true'
        );

        console.log('📦 Notification service returned:', typeof result);

        // CRITICAL FIX: Always ensure we return a flat array
        let notificationsArray = [];

        if (result && typeof result === 'object') {
            if (Array.isArray(result)) {
                // Service returned array directly
                notificationsArray = result;
            } else if (result.notifications && Array.isArray(result.notifications)) {
                // Service returned object with notifications property
                notificationsArray = result.notifications;
            }
        }

        // Clean the notifications to ensure proper structure
        const cleanedNotifications = notificationsArray.map(notification => {
            const cleaned = {
                _id: notification._id,
                recipient: notification.recipient,
                type: notification.type || 'general',
                title: notification.title || '',
                message: notification.message || '',
                isRead: notification.isRead || false,
                createdAt: notification.createdAt,
                readAt: notification.readAt || null,
                data: notification.data || {},
                // Properly handle populated fields
                sender: notification.sender ? {
                    _id: notification.sender._id || notification.sender,
                    name: notification.sender.name || 'Unknown',
                    email: notification.sender.email || '',
                    avatar: notification.sender.avatar || null
                } : null,
                team: notification.team ? {
                    _id: notification.team._id || notification.team,
                    name: notification.team.name || 'Unknown Team'
                } : null,
                task: notification.task ? {
                    _id: notification.task._id || notification.task,
                    name: notification.task.name || 'Unknown Task'
                } : null
            };

            return cleaned;
        });

        console.log(`✅ Returning ${cleanedNotifications.length} cleaned notifications`);
        res.json(cleanedNotifications);

    } catch (err) {
        console.error('❌ Get notifications error:', err);
        // Return empty array instead of error for non-critical feature
        res.json([]);
    }
};

// Mark notification as read
export const markAsRead = async (req, res) => {
    try {
        const { notificationId } = req.params;
        const userId = req.userId;

        const notification = await markNotificationAsRead(notificationId, userId);

        if (!notification) {
            return res.status(404).json({ message: 'Notification not found' });
        }

        res.json({
            message: 'Notification marked as read',
            notification
        });
    } catch (err) {
        console.error('Mark as read error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Mark all notifications as read
export const markAllAsRead = async (req, res) => {
    try {
        const userId = req.userId;
        const result = await markAllNotificationsAsRead(userId);

        res.json({
            message: `${result.modifiedCount || 0} notifications marked as read`
        });
    } catch (err) {
        console.error('Mark all as read error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Update FCM token
export const updateToken = async (req, res) => {
    try {
        const { token, platform = 'android' } = req.body;
        const userId = req.userId;

        if (!token) {
            return res.status(400).json({ message: 'FCM token is required' });
        }

        const result = await updateFCMToken(userId, token, platform);

        res.json({
            message: 'FCM token updated successfully',
            result
        });
    } catch (err) {
        console.error('Update FCM token error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};