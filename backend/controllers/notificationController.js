
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

        const result = await getUserNotifications(
            userId,
            parseInt(limit),
            parseInt(offset),
            unreadOnly === 'true'
        );

        // 🔧 FIX: Always return array format for consistency
        // If result has notifications property, return the array
        // Otherwise return empty array
        if (result && Array.isArray(result.notifications)) {
            res.json(result.notifications);
        } else if (Array.isArray(result)) {
            res.json(result);
        } else {
            console.log('No notifications found, returning empty array');
            res.json([]);
        }
    } catch (err) {
        console.error('Get notifications error:', err);
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