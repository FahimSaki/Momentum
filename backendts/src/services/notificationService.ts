import admin from 'firebase-admin';
import Notification from '../models/Notification';
import User from '../models/User';
import { ITaskDocument, IUserDocument, NotificationPayload } from '../types/interfaces';
import { Types } from 'mongoose';
import serviceAccount from "../../momentum-51138-firebase-adminsdk-fbsvc-f3005dd37f.json";

// ── Firebase initialisation ───────────────────────────────────────────────

let firebaseInitialised = false;

export const initFirebase = (): void => {
    if (firebaseInitialised || admin.apps.length) { firebaseInitialised = true; return; }

    try {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
        });

        firebaseInitialised = true;
        console.log('✅ Firebase initialised');
    } catch (err) {
        console.error('❌ Firebase init failed:', err);
    }
};

// ── Send FCM to one user ──────────────────────────────────────────────────

export const sendNotification = async (
    userId: string,
    payload: NotificationPayload
): Promise<boolean> => {
    if (!firebaseInitialised) return false;

    try {
        const user = await User.findById(userId).select('fcmTokens fcmToken');
        if (!user) return false;

        const tokens: string[] = [];
        if (user.fcmTokens?.length) tokens.push(...user.fcmTokens.map((t) => t.token));
        else if (user.fcmToken) tokens.push(user.fcmToken);

        if (!tokens.length) return false;

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

        const results = await Promise.allSettled(
            tokens.map((token) =>
                admin.messaging().send({
                    token,
                    notification: { title: payload.title, body: payload.body },
                    data: dataMap,
                    android: { priority: 'high', notification: { channelId: 'default', sound: 'default' } },
                    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
                })
            )
        );

        const stale: string[] = [];
        results.forEach((r, i) => {
            if (r.status === 'rejected') {
                const code = (r.reason as any)?.errorInfo?.code ?? '';
                if (['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(code)) {
                    stale.push(tokens[i]);
                }
            }
        });

        if (stale.length) {
            await User.findByIdAndUpdate(userId, { $pull: { fcmTokens: { token: { $in: stale } } } });
        }

        return results.some((r) => r.status === 'fulfilled');
    } catch (err) {
        console.error('sendNotification error:', err);
        return false;
    }
};

// ── Task assigned ─────────────────────────────────────────────────────────

export const sendTaskAssignedNotification = async (
    task: ITaskDocument,
    assigner: IUserDocument,
    recipientIds: string[]
): Promise<void> => {
    for (const recipientId of recipientIds) {
        try {
            const notif = await Notification.create({
                recipient: new Types.ObjectId(recipientId),
                sender: assigner._id,
                task: task._id,
                team: task.team,
                type: 'task_assigned',
                title: 'New Task Assigned',
                message: `${assigner.name} assigned you: "${task.name}"`,
                data: { taskId: task._id, taskName: task.name, assignerName: assigner.name },
            });

            await sendNotification(recipientId, {
                type: 'task_assigned',
                title: 'New Task Assigned',
                body: `${assigner.name} assigned you: "${task.name}"`,
                senderId: assigner._id,
                taskId: task._id,
                teamId: task.team,
                notificationId: notif._id.toString(),
            });
        } catch (err) {
            console.error(`Notification failed for ${recipientId}:`, err);
        }
    }
};

// ── Task completed ────────────────────────────────────────────────────────

export const sendTaskCompletedNotification = async (
    task: ITaskDocument,
    completer: IUserDocument,
    recipientId: Types.ObjectId | string
): Promise<void> => {
    try {
        const notif = await Notification.create({
            recipient: new Types.ObjectId(recipientId.toString()),
            sender: completer._id,
            task: task._id,
            team: task.team,
            type: 'task_completed',
            title: 'Task Completed',
            message: `${completer.name} completed: "${task.name}"`,
            data: { taskId: task._id, taskName: task.name, completerName: completer.name },
        });

        await sendNotification(recipientId.toString(), {
            type: 'task_completed',
            title: 'Task Completed',
            body: `${completer.name} completed: "${task.name}"`,
            senderId: completer._id,
            taskId: task._id,
            teamId: task.team,
            notificationId: notif._id.toString(),
        });
    } catch (err) {
        console.error('sendTaskCompletedNotification error:', err);
    }
};