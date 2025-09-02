import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
// ADD THESE MISSING IMPORTS
import User from '../models/User.js';
import Notification from '../models/Notification.js';
import Task from '../models/Task.js';

// Try multiple possible locations for the service account
const getServiceAccountPath = () => {
    // 1. Explicit env var path (you can set FIREBASE_SERVICE_ACCOUNT_PATH in Render or locally)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
        return process.env.FIREBASE_SERVICE_ACCOUNT_PATH; // if I set the path in environment variable
    }

    // 2. Render Secret Files default mount
    const renderPath = '/etc/secrets/momentum-api-fcm-761b4eb73e69.json';
    if (fs.existsSync(renderPath)) {
        return renderPath;
    }

    // 3. Local development (project root)
    const localPath = path.resolve('momentum-api-fcm-761b4eb73e69.json');
    if (fs.existsSync(localPath)) {
        return localPath;
    }

    return null; // nothing found
};

const initializeFirebase = () => {
    if (!admin.apps.length) {
        const serviceAccountPath = getServiceAccountPath();

        if (!serviceAccountPath) {
            console.warn('⚠️ Firebase service account file not found in any known location');
            return false;
        }

        try {
            const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });

            console.log(`✅ Firebase Admin SDK initialized using ${serviceAccountPath}`);
            return true;
        } catch (error) {
            console.error('❌ Firebase initialization error:', error.message);
            return false;
        }
    }
    return true;
};

const isFirebaseInitialized = initializeFirebase();

// Send notification to a specific user
export const sendNotification = async (userId, notificationData, saveToDb = true) => {
    try {
        const user = await User.findById(userId);
        if (!user) {
            console.error('User not found:', userId);
            return null;
        }

        // Check if user has push notifications enabled
        if (!user.notificationSettings?.push && !user.notificationSettings?.inApp) {
            console.log('User has disabled notifications:', userId);
            return null;
        }

        let fcmResponse = null;

        // Send FCM notification only if Firebase is initialized and user has push notifications enabled
        if (isFirebaseInitialized && user.notificationSettings?.push && user.fcmTokens?.length > 0) {
            const validTokens = user.fcmTokens.filter(tokenData =>
                tokenData.token && tokenData.lastUsed > new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // 30 days
            );

            if (validTokens.length > 0) {
                const tokens = validTokens.map(t => t.token);

                const message = {
                    notification: {
                        title: notificationData.title,
                        body: notificationData.body,
                    },
                    data: {
                        ...notificationData.data,
                        // Convert all data values to strings for FCM
                        ...Object.fromEntries(
                            Object.entries(notificationData.data || {}).map(([k, v]) => [k, String(v)])
                        )
                    },
                    tokens: tokens,
                };

                try {
                    fcmResponse = await admin.messaging().sendMulticast(message);

                    // Clean up invalid tokens
                    const failedTokens = [];
                    fcmResponse.responses.forEach((resp, idx) => {
                        if (!resp.success) {
                            console.error('FCM Error:', resp.error);
                            if (resp.error?.code === 'messaging/registration-token-not-registered') {
                                failedTokens.push(tokens[idx]);
                            }
                        }
                    });

                    // Remove invalid tokens from user record
                    if (failedTokens.length > 0) {
                        await User.findByIdAndUpdate(userId, {
                            $pull: {
                                fcmTokens: { token: { $in: failedTokens } }
                            }
                        });
                    }

                    console.log(`✅ FCM notification sent to ${fcmResponse.successCount}/${tokens.length} tokens`);
                } catch (fcmError) {
                    console.error('FCM Send Error:', fcmError);
                }
            }
        } else if (!isFirebaseInitialized && user.notificationSettings?.push) {
            console.log('⚠️  Firebase not initialized - skipping push notification');
        }

        // Save in-app notification to database
        if (saveToDb && user.notificationSettings?.inApp) {
            const dbNotification = new Notification({
                recipient: userId,
                sender: notificationData.senderId,
                team: notificationData.teamId,
                task: notificationData.taskId,
                type: notificationData.type,
                title: notificationData.title,
                message: notificationData.body,
                data: notificationData.data,
                isSent: fcmResponse?.successCount > 0,
                fcmMessageId: fcmResponse?.responses?.[0]?.messageId
            });

            await dbNotification.save();
            console.log('✅ In-app notification saved to database');
        }

        return {
            fcmResponse,
            saved: saveToDb
        };

    } catch (error) {
        console.error('Send notification error:', error);
        return null;
    }
};

// Send notification to multiple users
export const sendBulkNotification = async (userIds, notificationData, saveToDb = true) => {
    const results = await Promise.allSettled(
        userIds.map(userId => sendNotification(userId, notificationData, saveToDb))
    );

    const successful = results.filter(r => r.status === 'fulfilled' && r.value).length;
    console.log(`✅ Bulk notification: ${successful}/${userIds.length} successful`);

    return results;
};

// Update user's FCM token
export const updateFCMToken = async (userId, token, platform = 'android') => {
    try {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }

        // Remove old token if it exists
        user.fcmTokens = user.fcmTokens.filter(t => t.token !== token);

        // Add new/updated token
        user.fcmTokens.push({
            token,
            platform,
            lastUsed: new Date()
        });

        // Keep only the 5 most recent tokens per user (to handle multiple devices)
        user.fcmTokens = user.fcmTokens
            .sort((a, b) => b.lastUsed - a.lastUsed)
            .slice(0, 5);

        await user.save();
        console.log(`✅ FCM token updated for user ${userId}`);

        return { success: true };
    } catch (error) {
        console.error('Update FCM token error:', error);
        throw error;
    }
};

// Get user's notifications
export const getUserNotifications = async (userId, limit = 50, offset = 0, unreadOnly = false) => {
    try {
        const query = { recipient: userId };
        if (unreadOnly) {
            query.isRead = false;
        }

        const notifications = await Notification.find(query)
            .populate('sender', 'name email avatar')
            .populate('team', 'name')
            .populate('task', 'name')
            .sort({ createdAt: -1 })
            .limit(limit)
            .skip(offset);

        const totalCount = await Notification.countDocuments(query);
        const unreadCount = await Notification.countDocuments({
            recipient: userId,
            isRead: false
        });

        return {
            notifications,
            totalCount,
            unreadCount,
            hasMore: offset + notifications.length < totalCount
        };
    } catch (error) {
        console.error('Get user notifications error:', error);
        throw error;
    }
};

// Mark notification as read
export const markNotificationAsRead = async (notificationId, userId) => {
    try {
        const notification = await Notification.findOneAndUpdate(
            { _id: notificationId, recipient: userId },
            {
                isRead: true,
                readAt: new Date()
            },
            { new: true }
        );

        return notification;
    } catch (error) {
        console.error('Mark notification as read error:', error);
        throw error;
    }
};

// Mark all notifications as read for a user
export const markAllNotificationsAsRead = async (userId) => {
    try {
        const result = await Notification.updateMany(
            { recipient: userId, isRead: false },
            {
                isRead: true,
                readAt: new Date()
            }
        );

        return result;
    } catch (error) {
        console.error('Mark all notifications as read error:', error);
        throw error;
    }
};

// Clean up old notifications (run this periodically)
export const cleanupOldNotifications = async (daysOld = 30) => {
    try {
        const cutoffDate = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);

        const result = await Notification.deleteMany({
            createdAt: { $lt: cutoffDate },
            isRead: true
        });

        console.log(`✅ Cleaned up ${result.deletedCount} old notifications`);
        return result;
    } catch (error) {
        console.error('Cleanup old notifications error:', error);
        throw error;
    }
};

// Send task assignment notification
export const sendTaskAssignedNotification = async (taskData, assignerData, assigneeIds) => {
    const notificationData = {
        type: 'task_assigned',
        title: 'New Task Assigned',
        body: `${assignerData.name} assigned you a task: "${taskData.name}"`,
        senderId: assignerData._id,
        taskId: taskData._id,
        teamId: taskData.team,
        data: {
            type: 'task_assigned',
            taskId: taskData._id.toString(),
            taskName: taskData.name,
            assignerName: assignerData.name,
            teamId: taskData.team?.toString(),
            dueDate: taskData.dueDate?.toISOString(),
            priority: taskData.priority
        }
    };

    return await sendBulkNotification(assigneeIds, notificationData);
};

// Send task completion notification
export const sendTaskCompletedNotification = async (taskData, completerData, assignerId) => {
    const notificationData = {
        type: 'task_completed',
        title: 'Task Completed',
        body: `${completerData.name} completed the task: "${taskData.name}"`,
        senderId: completerData._id,
        taskId: taskData._id,
        teamId: taskData.team,
        data: {
            type: 'task_completed',
            taskId: taskData._id.toString(),
            taskName: taskData.name,
            completerName: completerData.name,
            teamId: taskData.team?.toString(),
            completedAt: new Date().toISOString()
        }
    };

    return await sendNotification(assignerId, notificationData);
};

// Send due date reminder notifications
export const sendDueDateReminders = async () => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);

        const nextDay = new Date(tomorrow);
        nextDay.setDate(nextDay.getDate() + 1);

        // Find tasks due tomorrow
        const dueTasks = await Task.find({
            dueDate: {
                $gte: tomorrow,
                $lt: nextDay
            },
            isArchived: false
        })
            .populate('assignedTo', 'name email')
            .populate('assignedBy', 'name email')
            .populate('team', 'name');

        for (const task of dueTasks) {
            const notificationData = {
                type: 'task_due_reminder',
                title: 'Task Due Tomorrow',
                body: `Don't forget: "${task.name}" is due tomorrow`,
                senderId: task.assignedBy?._id,
                taskId: task._id,
                teamId: task.team?._id,
                data: {
                    type: 'task_due_reminder',
                    taskId: task._id.toString(),
                    taskName: task.name,
                    dueDate: task.dueDate.toISOString(),
                    teamName: task.team?.name
                }
            };

            const assigneeIds = task.assignedTo.map(user => user._id);
            await sendBulkNotification(assigneeIds, notificationData);
        }

        console.log(`✅ Sent due date reminders for ${dueTasks.length} tasks`);
        return dueTasks.length;
    } catch (error) {
        console.error('Send due date reminders error:', error);
        throw error;
    }
};