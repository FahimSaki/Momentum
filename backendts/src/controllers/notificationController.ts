import { Request, Response } from 'express';
import Notification from '../models/Notification';

// ── Get notifications ─────────────────────────────────────────────────────

export const getNotifications = async (req: Request, res: Response): Promise<void> => {
    try {
        const { page = '1', limit = '20', unreadOnly = 'false' } = req.query as Record<string, string>;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(50, parseInt(limit));
        const skip = (pageNum - 1) * limitNum;

        const query: Record<string, unknown> = { recipient: req.userId };
        if (unreadOnly === 'true') query.isRead = false;

        const [notifications, total, unreadCount] = await Promise.all([
            Notification.find(query)
                .populate('sender', 'name email avatar')
                .populate('team', 'name')
                .populate('task', 'name')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limitNum),
            Notification.countDocuments(query),
            Notification.countDocuments({ recipient: req.userId, isRead: false }),
        ]);

        res.json({
            notifications,
            pagination: { page: pageNum, limit: limitNum, total, pages: Math.ceil(total / limitNum) },
            unreadCount,
        });
    } catch (err) {
        console.error('Get notifications error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Mark as read ──────────────────────────────────────────────────────────

export const markAsRead = async (req: Request, res: Response): Promise<void> => {
    try {
        const { notificationId } = req.params;

        const notification = await Notification.findOneAndUpdate(
            { _id: notificationId, recipient: req.userId },
            { isRead: true, readAt: new Date() },
            { new: true }
        );

        if (!notification) { res.status(404).json({ message: 'Notification not found' }); return; }
        res.json({ message: 'Notification marked as read', notification });
    } catch (err) {
        console.error('Mark as read error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Mark all as read ──────────────────────────────────────────────────────

export const markAllAsRead = async (req: Request, res: Response): Promise<void> => {
    try {
        const result = await Notification.updateMany(
            { recipient: req.userId, isRead: false },
            { isRead: true, readAt: new Date() }
        );
        res.json({ message: 'All notifications marked as read', count: result.modifiedCount });
    } catch (err) {
        console.error('Mark all as read error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Delete notification ───────────────────────────────────────────────────

export const deleteNotification = async (req: Request, res: Response): Promise<void> => {
    try {
        const { notificationId } = req.params;
        const result = await Notification.findOneAndDelete({ _id: notificationId, recipient: req.userId });
        if (!result) { res.status(404).json({ message: 'Notification not found' }); return; }
        res.json({ message: 'Notification deleted' });
    } catch (err) {
        console.error('Delete notification error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get unread count ──────────────────────────────────────────────────────

export const getUnreadCount = async (req: Request, res: Response): Promise<void> => {
    try {
        const count = await Notification.countDocuments({ recipient: req.userId, isRead: false });
        res.json({ count });
    } catch (err) {
        console.error('Get unread count error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};