"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUnreadCount = exports.deleteNotification = exports.markAllAsRead = exports.markAsRead = exports.getNotifications = void 0;
const Notification_1 = __importDefault(require("../models/Notification"));
// ── Get notifications ─────────────────────────────────────────────────────
const getNotifications = async (req, res) => {
    try {
        const { page = '1', limit = '20', unreadOnly = 'false' } = req.query;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(50, parseInt(limit));
        const skip = (pageNum - 1) * limitNum;
        const query = { recipient: req.userId };
        if (unreadOnly === 'true')
            query.isRead = false;
        const [notifications, total, unreadCount] = await Promise.all([
            Notification_1.default.find(query)
                .populate('sender', 'name email avatar')
                .populate('team', 'name')
                .populate('task', 'name')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limitNum),
            Notification_1.default.countDocuments(query),
            Notification_1.default.countDocuments({ recipient: req.userId, isRead: false }),
        ]);
        res.json({
            notifications,
            pagination: { page: pageNum, limit: limitNum, total, pages: Math.ceil(total / limitNum) },
            unreadCount,
        });
    }
    catch (err) {
        console.error('Get notifications error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getNotifications = getNotifications;
// ── Mark as read ──────────────────────────────────────────────────────────
const markAsRead = async (req, res) => {
    try {
        const { notificationId } = req.params;
        const notification = await Notification_1.default.findOneAndUpdate({ _id: notificationId, recipient: req.userId }, { isRead: true, readAt: new Date() }, { new: true });
        if (!notification) {
            res.status(404).json({ message: 'Notification not found' });
            return;
        }
        res.json({ message: 'Notification marked as read', notification });
    }
    catch (err) {
        console.error('Mark as read error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.markAsRead = markAsRead;
// ── Mark all as read ──────────────────────────────────────────────────────
const markAllAsRead = async (req, res) => {
    try {
        const result = await Notification_1.default.updateMany({ recipient: req.userId, isRead: false }, { isRead: true, readAt: new Date() });
        res.json({ message: 'All notifications marked as read', count: result.modifiedCount });
    }
    catch (err) {
        console.error('Mark all as read error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.markAllAsRead = markAllAsRead;
// ── Delete notification ───────────────────────────────────────────────────
const deleteNotification = async (req, res) => {
    try {
        const { notificationId } = req.params;
        const result = await Notification_1.default.findOneAndDelete({ _id: notificationId, recipient: req.userId });
        if (!result) {
            res.status(404).json({ message: 'Notification not found' });
            return;
        }
        res.json({ message: 'Notification deleted' });
    }
    catch (err) {
        console.error('Delete notification error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.deleteNotification = deleteNotification;
// ── Get unread count ──────────────────────────────────────────────────────
const getUnreadCount = async (req, res) => {
    try {
        const count = await Notification_1.default.countDocuments({ recipient: req.userId, isRead: false });
        res.json({ count });
    }
    catch (err) {
        console.error('Get unread count error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getUnreadCount = getUnreadCount;
//# sourceMappingURL=notificationController.js.map