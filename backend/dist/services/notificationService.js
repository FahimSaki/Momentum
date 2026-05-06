"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.markAllNotificationsAsRead = exports.markNotificationAsRead = exports.getUserNotifications = exports.cleanupOldNotifications = exports.sendDueDateReminders = exports.sendTaskCompletedNotification = exports.sendTaskAssignedNotification = exports.updateFCMToken = exports.sendNotification = exports.initFirebase = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const Notification_1 = __importDefault(require("../models/Notification"));
const Task_1 = __importDefault(require("../models/Task"));
const User_1 = __importDefault(require("../models/User"));
const mongoose_1 = require("mongoose");
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
// ── Firebase init ──────────────────────────────────────────────────────────
let firebaseInitialised = false;
const initFirebase = () => {
    if (firebaseInitialised || firebase_admin_1.default.apps.length) {
        firebaseInitialised = true;
        return;
    }
    try {
        let serviceAccount;
        // ── Render / production ─────────────────────────────
        if (process.env.NODE_ENV === 'production') {
            const filePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
                || '/etc/secrets/momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json';
            serviceAccount = JSON.parse(fs_1.default.readFileSync(filePath, 'utf8'));
        }
        // ── Local development ───────────────────────────────
        else {
            const localPath = path_1.default.join(__dirname, '../../momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json');
            serviceAccount = require(localPath);
        }
        firebase_admin_1.default.initializeApp({
            credential: firebase_admin_1.default.credential.cert(serviceAccount),
        });
        firebaseInitialised = true;
        console.log('✅ Firebase initialised');
    }
    catch (err) {
        console.error('❌ Firebase init failed:', err);
    }
};
exports.initFirebase = initFirebase;
// ── Send FCM to one user ──────────────────────────────────────────────────
const sendNotification = async (userId, payload) => {
    if (!firebaseInitialised)
        return false;
    try {
        const user = await User_1.default.findById(userId).select('fcmTokens fcmToken');
        if (!user)
            return false;
        const tokens = [];
        if (user.fcmTokens?.length)
            tokens.push(...user.fcmTokens.map((t) => t.token));
        else if (user.fcmToken)
            tokens.push(user.fcmToken);
        if (!tokens.length)
            return false;
        const dataMap = {
            type: payload.type ?? '',
            title: payload.title,
            body: payload.body,
            senderId: payload.senderId?.toString() ?? '',
            taskId: payload.taskId?.toString() ?? '',
            teamId: payload.teamId?.toString() ?? '',
            notificationId: payload.notificationId ?? '',
            ...(payload.data ?? {}),
        };
        const stale = [];
        await Promise.allSettled(tokens.map(async (token) => {
            try {
                await firebase_admin_1.default.messaging().send({
                    token, notification: { title: payload.title, body: payload.body }, data: dataMap,
                    android: { priority: 'high', notification: { channelId: 'default', sound: 'default' } },
                    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
                });
            }
            catch (err) {
                const code = err?.errorInfo?.code ?? '';
                if (['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(code))
                    stale.push(token);
            }
        }));
        if (stale.length)
            await User_1.default.findByIdAndUpdate(userId, { $pull: { fcmTokens: { token: { $in: stale } } } });
        return true;
    }
    catch (err) {
        console.error('sendNotification error:', err);
        return false;
    }
};
exports.sendNotification = sendNotification;
// ── Update FCM token ──────────────────────────────────────────────────────
const updateFCMToken = async (userId, token, platform = 'android') => {
    const user = await User_1.default.findById(userId);
    if (!user)
        throw new Error('User not found');
    user.fcmTokens = user.fcmTokens.filter((t) => t.token !== token);
    user.fcmTokens.push({ token, platform: platform, lastUsed: new Date() });
    user.fcmTokens = user.fcmTokens.sort((a, b) => b.lastUsed.getTime() - a.lastUsed.getTime()).slice(0, 5);
    await user.save();
};
exports.updateFCMToken = updateFCMToken;
// ── Task assigned notification ────────────────────────────────────────────
const sendTaskAssignedNotification = async (task, assigner, recipientIds) => {
    for (const recipientId of recipientIds) {
        try {
            const notif = await Notification_1.default.create({
                recipient: new mongoose_1.Types.ObjectId(recipientId), sender: assigner._id,
                task: task._id, team: task.team, type: 'task_assigned',
                title: 'New Task Assigned',
                message: `${assigner.name} assigned you: "${task.name}"`,
                data: { taskId: task._id.toString(), taskName: task.name, assignerName: assigner.name },
            });
            await (0, exports.sendNotification)(recipientId, {
                type: 'task_assigned', title: 'New Task Assigned',
                body: `${assigner.name} assigned you: "${task.name}"`,
                senderId: assigner._id, taskId: task._id, teamId: task.team,
                notificationId: notif._id.toString(),
            });
        }
        catch (err) {
            console.error(`Notification failed for ${recipientId}:`, err);
        }
    }
};
exports.sendTaskAssignedNotification = sendTaskAssignedNotification;
// ── Task completed notification ───────────────────────────────────────────
const sendTaskCompletedNotification = async (task, completer, recipientId) => {
    try {
        const notif = await Notification_1.default.create({
            recipient: new mongoose_1.Types.ObjectId(recipientId.toString()), sender: completer._id,
            task: task._id, team: task.team, type: 'task_completed',
            title: 'Task Completed',
            message: `${completer.name} completed: "${task.name}"`,
            data: { taskId: task._id.toString(), taskName: task.name, completerName: completer.name },
        });
        await (0, exports.sendNotification)(recipientId.toString(), {
            type: 'task_completed', title: 'Task Completed',
            body: `${completer.name} completed: "${task.name}"`,
            senderId: completer._id, taskId: task._id, teamId: task.team,
            notificationId: notif._id.toString(),
        });
    }
    catch (err) {
        console.error('sendTaskCompletedNotification error:', err);
    }
};
exports.sendTaskCompletedNotification = sendTaskCompletedNotification;
// ── Due date reminders ────────────────────────────────────────────────────
const sendDueDateReminders = async () => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);
        const dayAfter = new Date(tomorrow);
        dayAfter.setDate(dayAfter.getDate() + 1);
        const tasks = await Task_1.default.find({ dueDate: { $gte: tomorrow, $lt: dayAfter }, isArchived: false })
            .populate('assignedTo', 'name email fcmTokens fcmToken notificationSettings')
            .populate('assignedBy', 'name email')
            .populate('team', 'name');
        console.log(`⏰ Found ${tasks.length} tasks due tomorrow`);
        let sent = 0;
        for (const task of tasks) {
            try {
                const teamName = task.team?.name ?? 'Personal';
                for (const assignee of task.assignedTo) {
                    await Notification_1.default.create({
                        recipient: assignee._id, sender: task.assignedBy,
                        task: task._id, team: task.team, type: 'task_due_reminder',
                        title: 'Task Due Tomorrow',
                        message: `"${task.name}" in ${teamName} is due tomorrow`,
                    });
                    await (0, exports.sendNotification)(assignee._id.toString(), {
                        type: 'task_due_reminder', title: 'Task Due Tomorrow',
                        body: `"${task.name}" in ${teamName} is due tomorrow`,
                        taskId: task._id, teamId: task.team,
                    });
                    sent++;
                }
            }
            catch (err) {
                console.error(`Reminder error for task ${task._id}:`, err);
            }
        }
        console.log(`✅ Sent ${sent} due date reminders`);
        return sent;
    }
    catch (err) {
        console.error('sendDueDateReminders error:', err);
        return 0;
    }
};
exports.sendDueDateReminders = sendDueDateReminders;
// ── Cleanup old notifications ─────────────────────────────────────────────
const cleanupOldNotifications = async (daysOld = 30) => {
    try {
        const cutoff = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);
        const result = await Notification_1.default.deleteMany({ createdAt: { $lt: cutoff }, isRead: true });
        console.log(`🧹 Deleted ${result.deletedCount} old notifications (>${daysOld} days)`);
        return result.deletedCount;
    }
    catch (err) {
        console.error('cleanupOldNotifications error:', err);
        return 0;
    }
};
exports.cleanupOldNotifications = cleanupOldNotifications;
// ── Get user notifications ────────────────────────────────────────────────
const getUserNotifications = async (userId, limit = 50, offset = 0, unreadOnly = false) => {
    const query = { recipient: userId };
    if (unreadOnly)
        query.isRead = false;
    const [notifications, totalCount, unreadCount] = await Promise.all([
        Notification_1.default.find(query)
            .populate('sender', 'name email avatar')
            .populate('team', 'name')
            .populate('task', 'name')
            .sort({ createdAt: -1 }).limit(limit).skip(offset).lean(),
        Notification_1.default.countDocuments(query),
        Notification_1.default.countDocuments({ recipient: userId, isRead: false }),
    ]);
    return { notifications, totalCount, unreadCount };
};
exports.getUserNotifications = getUserNotifications;
// ── Mark as read ──────────────────────────────────────────────────────────
const markNotificationAsRead = async (notificationId, userId) => Notification_1.default.findOneAndUpdate({ _id: notificationId, recipient: userId }, { isRead: true, readAt: new Date() }, { new: true });
exports.markNotificationAsRead = markNotificationAsRead;
// ── Mark all as read ──────────────────────────────────────────────────────
const markAllNotificationsAsRead = async (userId) => Notification_1.default.updateMany({ recipient: userId, isRead: false }, { isRead: true, readAt: new Date() });
exports.markAllNotificationsAsRead = markAllNotificationsAsRead;
//# sourceMappingURL=notificationService.js.map