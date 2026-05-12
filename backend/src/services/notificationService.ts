import admin from 'firebase-admin';
import Notification from '../models/Notification';
import Task from '../models/Task';
import User from '../models/User';
import { ITaskDocument, IUserDocument, NotificationPayload } from '../types/interfaces';
import { Types } from 'mongoose';
import fs from 'fs';
import path from 'path';

// ── Firebase init ──────────────────────────────────────────────────────────
let firebaseInitialised = false;

export const initFirebase = (): void => {
    if (firebaseInitialised || admin.apps.length) { firebaseInitialised = true; return; }
    try {
        let serviceAccount: object | undefined;
        let source = '';

        // Option 1: full JSON string in env var (safest for cloud hosting)
        if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
            serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
            source = 'FIREBASE_SERVICE_ACCOUNT_JSON env var';
        }
        // Option 2: explicit file path in env var
        else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
            serviceAccount = JSON.parse(
                fs.readFileSync(process.env.FIREBASE_SERVICE_ACCOUNT_PATH, 'utf8')
            );
            source = `file at ${process.env.FIREBASE_SERVICE_ACCOUNT_PATH}`;
        }
        // Option 3: Render mounted secret file (default path)
        else if (fs.existsSync('/etc/secrets/momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json')) {
            serviceAccount = JSON.parse(
                fs.readFileSync(
                    '/etc/secrets/momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json',
                    'utf8'
                )
            );
            source = 'Render mounted secret file';
        }
        // Option 4: local dev file relative to compiled output
        else {
            const localPath = path.join(
                __dirname,
                '../../momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json'
            );
            if (!fs.existsSync(localPath)) {
                console.warn('⚠️ Firebase: no service account found in any location — push notifications disabled');
                return;
            }
            serviceAccount = JSON.parse(fs.readFileSync(localPath, 'utf8'));
            source = `local dev file at ${localPath}`;
        }

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
        });

        firebaseInitialised = true;
        console.log(`✅ Firebase initialised (source: ${source})`);
    } catch (err) {
        console.error('❌ Firebase init failed:', err);
    }
};

// ── Send FCM to one user ──────────────────────────────────────────────────
export const sendNotification = async (
    userId: string,
    payload: NotificationPayload
): Promise<boolean> => {
    console.log('📡 ENTER sendNotification:', userId);

    if (!firebaseInitialised) {
        console.log('❌ Firebase not initialised');
        return false;
    }

    try {
        const user = await User.findById(userId).select('fcmTokens fcmToken');

        if (!user) {
            console.log('❌ User not found:', userId);
            return false;
        }

        const tokens: string[] = [];

        if (user.fcmTokens?.length) {
            tokens.push(...user.fcmTokens.map((t) => t.token));
        } else if (user.fcmToken) {
            tokens.push(user.fcmToken);
        }

        console.log('📲 Tokens resolved:', {
            userId,
            tokenCount: tokens.length,
        });

        if (!tokens.length) {
            console.log('❌ No FCM tokens found for user:', userId);
            return false;
        }

        const dataMap: Record<string, string> = {
            type: payload.type ?? '',
            title: payload.title,
            body: payload.body,
            senderId: payload.senderId?.toString() ?? '',
            taskId: payload.taskId?.toString() ?? '',
            teamId: payload.teamId?.toString() ?? '',
            notificationId: payload.notificationId ?? '',
            ...(payload.data ?? {}),
        };

        const stale: string[] = [];

        await Promise.allSettled(
            tokens.map(async (token) => {
                try {
                    await admin.messaging().send({
                        token,
                        notification: {
                            title: payload.title,
                            body: payload.body,
                        },
                        data: dataMap,
                        android: {
                            priority: 'high',
                            notification: {
                                channelId: 'default',
                                sound: 'default',
                            },
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default',
                                    badge: 1,
                                },
                            },
                        },
                    });
                } catch (err: any) {
                    const code = err?.errorInfo?.code ?? '';
                    if (
                        [
                            'messaging/invalid-registration-token',
                            'messaging/registration-token-not-registered',
                        ].includes(code)
                    ) {
                        stale.push(token);
                    }
                }
            })
        );

        if (stale.length) {
            await User.findByIdAndUpdate(userId, {
                $pull: { fcmTokens: { token: { $in: stale } } },
            });
        }

        console.log('📲 SEND FINISHED:', {
            userId,
            tokenCount: tokens.length,
            staleRemoved: stale.length,
        });

        return true;
    } catch (err) {
        console.error('❌ sendNotification error:', err);
        return false;
    }
};

// ── Update FCM token ──────────────────────────────────────────────────────
export const updateFCMToken = async (userId: string, token: string, platform = 'android'): Promise<void> => {
    const user = await User.findById(userId);
    if (!user) throw new Error('User not found');
    user.fcmTokens = user.fcmTokens.filter((t) => t.token !== token);
    user.fcmTokens.push({ token, platform: platform as any, lastUsed: new Date() });
    user.fcmTokens = user.fcmTokens.sort((a, b) => b.lastUsed.getTime() - a.lastUsed.getTime()).slice(0, 5);
    await user.save();
};

// ── Task assigned notification ────────────────────────────────────────────
export const sendTaskAssignedNotification = async (
    task: ITaskDocument, assigner: IUserDocument, recipientIds: string[]
): Promise<void> => {
    for (const recipientId of recipientIds) {
        try {
            const notif = await Notification.create({
                recipient: new Types.ObjectId(recipientId), sender: assigner._id,
                task: task._id, team: task.team, type: 'task_assigned',
                title: 'New Task Assigned',
                message: `${assigner.name} assigned you: "${task.name}"`,
                data: { taskId: task._id.toString(), taskName: task.name, assignerName: assigner.name },
            });
            await sendNotification(recipientId, {
                type: 'task_assigned', title: 'New Task Assigned',
                body: `${assigner.name} assigned you: "${task.name}"`,
                senderId: assigner._id, taskId: task._id, teamId: task.team,
                notificationId: notif._id.toString(),
            });
        } catch (err) { console.error(`Notification failed for ${recipientId}:`, err); }
    }
};

// ── Task completed notification ───────────────────────────────────────────
export const sendTaskCompletedNotification = async (
    task: ITaskDocument, completer: IUserDocument, recipientId: Types.ObjectId | string
): Promise<void> => {
    try {
        const notif = await Notification.create({
            recipient: new Types.ObjectId(recipientId.toString()), sender: completer._id,
            task: task._id, team: task.team, type: 'task_completed',
            title: 'Task Completed',
            message: `${completer.name} completed: "${task.name}"`,
            data: { taskId: task._id.toString(), taskName: task.name, completerName: completer.name },
        });
        await sendNotification(recipientId.toString(), {
            type: 'task_completed', title: 'Task Completed',
            body: `${completer.name} completed: "${task.name}"`,
            senderId: completer._id, taskId: task._id, teamId: task.team,
            notificationId: notif._id.toString(),
        });
    } catch (err) { console.error('sendTaskCompletedNotification error:', err); }
};

// ── Due date reminders ────────────────────────────────────────────────────
export const sendDueDateReminders = async (): Promise<number> => {
    try {
        const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); tomorrow.setHours(0, 0, 0, 0);
        const dayAfter = new Date(tomorrow); dayAfter.setDate(dayAfter.getDate() + 1);

        const tasks = await Task.find({ dueDate: { $gte: tomorrow, $lt: dayAfter }, isArchived: false })
            .populate('assignedTo', 'name email fcmTokens fcmToken notificationSettings')
            .populate('assignedBy', 'name email')
            .populate('team', 'name');

        console.log(`⏰ Found ${tasks.length} tasks due tomorrow`);
        let sent = 0;
        for (const task of tasks) {
            try {
                const teamName = (task.team as any)?.name ?? 'Personal';
                for (const assignee of task.assignedTo as any[]) {
                    await Notification.create({
                        recipient: assignee._id, sender: task.assignedBy,
                        task: task._id, team: task.team, type: 'task_due_reminder',
                        title: 'Task Due Tomorrow',
                        message: `"${task.name}" in ${teamName} is due tomorrow`,
                    });
                    await sendNotification(assignee._id.toString(), {
                        type: 'task_due_reminder', title: 'Task Due Tomorrow',
                        body: `"${task.name}" in ${teamName} is due tomorrow`,
                        taskId: task._id, teamId: task.team,
                    });
                    sent++;
                }
            } catch (err) { console.error(`Reminder error for task ${task._id}:`, err); }
        }
        console.log(`✅ Sent ${sent} due date reminders`);
        return sent;
    } catch (err) { console.error('sendDueDateReminders error:', err); return 0; }
};

// ── Cleanup old notifications ─────────────────────────────────────────────
export const cleanupOldNotifications = async (daysOld = 30): Promise<number> => {
    try {
        const cutoff = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);
        const result = await Notification.deleteMany({ createdAt: { $lt: cutoff }, isRead: true });
        console.log(`🧹 Deleted ${result.deletedCount} old notifications (>${daysOld} days)`);
        return result.deletedCount;
    } catch (err) { console.error('cleanupOldNotifications error:', err); return 0; }
};

// ── Get user notifications ────────────────────────────────────────────────
export const getUserNotifications = async (
    userId: string, limit = 50, offset = 0, unreadOnly = false
) => {
    const query: Record<string, unknown> = { recipient: userId };
    if (unreadOnly) query.isRead = false;
    const [notifications, totalCount, unreadCount] = await Promise.all([
        Notification.find(query)
            .populate('sender', 'name email avatar')
            .populate('team', 'name')
            .populate('task', 'name')
            .sort({ createdAt: -1 }).limit(limit).skip(offset).lean(),
        Notification.countDocuments(query),
        Notification.countDocuments({ recipient: userId, isRead: false }),
    ]);
    return { notifications, totalCount, unreadCount };
};

// ── Mark as read ──────────────────────────────────────────────────────────
export const markNotificationAsRead = async (notificationId: string, userId: string) =>
    Notification.findOneAndUpdate(
        { _id: notificationId, recipient: userId },
        { isRead: true, readAt: new Date() },
        { new: true }
    );

// ── Mark all as read ──────────────────────────────────────────────────────
export const markAllNotificationsAsRead = async (userId: string) =>
    Notification.updateMany({ recipient: userId, isRead: false }, { isRead: true, readAt: new Date() });