import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import User from '../models/User.js';
import Notification from '../models/Notification.js';
import Task from '../models/Task.js';

// SERVICE ACCOUNT DETECTION
const getServiceAccountPath = () => {
    // 1. Environment variable path (recommended for production)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
        const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
        if (fs.existsSync(envPath)) {
            console.log(`✅ Using Firebase service account from env var: ${envPath}`);
            return envPath;
        }
    }

    // 2. Check for service account JSON in environment variable
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        try {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
            // Write to temp file and return path
            const tempPath = '/tmp/firebase-service-account.json';
            fs.writeFileSync(tempPath, JSON.stringify(serviceAccount));
            console.log('✅ Using Firebase service account from env JSON');
            return tempPath;
        } catch (error) {
            console.warn('⚠️ Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:', error.message);
        }
    }

    // 3. Render.com secret files mount
    const renderPath = '/etc/secrets/momentum-api-fcm-761b4eb73e69.json';
    if (fs.existsSync(renderPath)) {
        console.log(`✅ Using Firebase service account from Render: ${renderPath}`);
        return renderPath;
    }

    // 4. Project root (local development)
    const localPath = path.resolve('momentum-api-fcm-761b4eb73e69.json');
    if (fs.existsSync(localPath)) {
        console.log(`✅ Using Firebase service account from project root: ${localPath}`);
        return localPath;
    }

    // 5. Check common paths
    const commonPaths = [
        './firebase-service-account.json',
        '../firebase-service-account.json',
        path.resolve(process.cwd(), 'firebase-service-account.json'),
        path.resolve(process.cwd(), 'config', 'firebase-service-account.json'),
    ];

    for (const commonPath of commonPaths) {
        if (fs.existsSync(commonPath)) {
            console.log(`✅ Using Firebase service account from: ${commonPath}`);
            return commonPath;
        }
    }

    console.warn('⚠️ Firebase service account file not found in any location');
    return null;
};

// FIREBASE INITIALIZATION
let isFirebaseInitialized = false;
const initializeFirebase = () => {
    if (admin.apps.length > 0) {
        console.log('✅ Firebase Admin SDK already initialized');
        isFirebaseInitialized = true;
        return true;
    }

    try {
        const serviceAccountPath = getServiceAccountPath();

        if (!serviceAccountPath) {
            console.warn('⚠️ Firebase service account not found - notifications will be disabled');
            isFirebaseInitialized = false;
            return false;
        }

        const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

        // Validate service account structure
        const requiredFields = ['type', 'project_id', 'private_key', 'client_email'];
        const missingFields = requiredFields.filter(field => !serviceAccount[field]);

        if (missingFields.length > 0) {
            console.error('❌ Invalid service account file - missing fields:', missingFields);
            isFirebaseInitialized = false;
            return false;
        }

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: serviceAccount.project_id,
        });

        console.log(`✅ Firebase Admin SDK initialized successfully`);
        console.log(`📱 Project ID: ${serviceAccount.project_id}`);
        isFirebaseInitialized = true;
        return true;

    } catch (error) {
        console.error('❌ Firebase initialization failed:', error.message);

        // Provide helpful error messages
        if (error.code === 'ENOENT') {
            console.error('💡 Service account file not found. Please check the file path.');
        } else if (error.message.includes('Parse error')) {
            console.error('💡 Service account file is not valid JSON. Please check the file format.');
        } else if (error.message.includes('private_key')) {
            console.error('💡 Service account private key is invalid. Please regenerate the file.');
        }

        isFirebaseInitialized = false;
        return false;
    }
};

// Initialize on module load
initializeFirebase();

// NOTIFICATION SENDING
export const sendNotification = async (userId, notificationData, saveToDb = true) => {
    try {
        const user = await User.findById(userId);
        if (!user) {
            console.error('❌ User not found:', userId);
            return null;
        }

        // Check user notification preferences
        if (!user.notificationSettings?.push && !user.notificationSettings?.inApp) {
            console.log(`ℹ️ User ${userId} has disabled notifications`);
            return null;
        }

        let fcmResponse = null;

        // FCM SENDING
        if (isFirebaseInitialized && user.notificationSettings?.push && user.fcmTokens?.length > 0) {
            try {
                // Filter valid tokens (active within last 60 days)
                const validTokens = user.fcmTokens.filter(tokenData => {
                    if (!tokenData.token) return false;
                    const daysSinceLastUsed = (Date.now() - new Date(tokenData.lastUsed).getTime()) / (1000 * 60 * 60 * 24);
                    return daysSinceLastUsed <= 60;
                });

                if (validTokens.length === 0) {
                    console.log(`ℹ️ No valid FCM tokens for user ${userId}`);
                } else {
                    const tokens = validTokens.map(t => t.token);
                    console.log(`📱 Sending FCM to ${tokens.length} token(s) for user ${userId}`);

                    // MESSAGE FORMAT
                    const message = {
                        notification: {
                            title: notificationData.title || 'Momentum Notification',
                            body: notificationData.body || 'You have a new notification',
                        },
                        data: {
                            // Convert all data to strings (FCM requirement)
                            type: notificationData.type || 'general',
                            userId: userId.toString(),
                            notificationId: notificationData.notificationId || '',
                            teamId: notificationData.teamId?.toString() || '',
                            taskId: notificationData.taskId?.toString() || '',
                            timestamp: new Date().toISOString(),
                            // Include all other data as strings
                            ...Object.fromEntries(
                                Object.entries(notificationData.data || {}).map(([k, v]) => [k, String(v)])
                            )
                        },
                        // ANDROID/IOS SPECIFIC CONFIGS
                        android: {
                            notification: {
                                sound: 'default',
                                channelId: 'momentum_notifications',
                                priority: 'high',
                            },
                            data: {
                                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                            }
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default',
                                    badge: 1,
                                }
                            }
                        },
                        tokens: tokens,
                    };

                    fcmResponse = await admin.messaging().sendMulticast(message);

                    // ERROR HANDLING
                    const invalidTokens = [];
                    fcmResponse.responses.forEach((resp, idx) => {
                        if (!resp.success) {
                            console.error(`❌ FCM Error for token ${idx}:`, resp.error?.code, resp.error?.message);

                            // Identify tokens to remove
                            if (['messaging/registration-token-not-registered',
                                'messaging/invalid-registration-token'].includes(resp.error?.code)) {
                                invalidTokens.push(tokens[idx]);
                            }
                        }
                    });

                    // Remove invalid tokens
                    if (invalidTokens.length > 0) {
                        console.log(`🧹 Removing ${invalidTokens.length} invalid FCM token(s)`);
                        await User.findByIdAndUpdate(userId, {
                            $pull: {
                                fcmTokens: { token: { $in: invalidTokens } }
                            }
                        });
                    }

                    console.log(`✅ FCM sent to ${fcmResponse.successCount}/${tokens.length} tokens`);
                }
            } catch (fcmError) {
                console.error('❌ FCM Send Error:', fcmError.code, fcmError.message);

                // Handle specific FCM errors
                if (fcmError.code === 'messaging/authentication-error') {
                    console.error('💡 FCM authentication failed - check service account credentials');
                } else if (fcmError.code === 'messaging/project-not-found') {
                    console.error('💡 FCM project not found - check project ID in service account');
                }
            }
        } else if (!isFirebaseInitialized && user.notificationSettings?.push) {
            console.log('⚠️ Firebase not initialized - skipping FCM notification');
        }

        // SAVE IN-APP NOTIFICATION
        if (saveToDb && user.notificationSettings?.inApp) {
            try {
                const dbNotification = new Notification({
                    recipient: userId,
                    sender: notificationData.senderId,
                    team: notificationData.teamId,
                    task: notificationData.taskId,
                    type: notificationData.type || 'general',
                    title: notificationData.title,
                    message: notificationData.body,
                    data: notificationData.data || {},
                    isSent: fcmResponse?.successCount > 0,
                    fcmMessageId: fcmResponse?.responses?.[0]?.messageId
                });

                await dbNotification.save();
                console.log('✅ In-app notification saved to database');
            } catch (dbError) {
                console.error('❌ Error saving notification to database:', dbError.message);
            }
        }

        return {
            fcmResponse,
            saved: saveToDb,
            fcmSent: fcmResponse?.successCount > 0,
            dbSaved: saveToDb && user.notificationSettings?.inApp
        };

    } catch (error) {
        console.error('❌ Send notification error:', error.message);
        return null;
    }
};

// FCM TOKEN MANAGEMENT
export const updateFCMToken = async (userId, token, platform = 'android') => {
    try {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }

        console.log(`📱 Updating FCM token for user ${userId} (${platform})`);

        // Remove old token if it exists
        user.fcmTokens = user.fcmTokens.filter(t => t.token !== token);

        // Add new/updated token
        user.fcmTokens.push({
            token,
            platform,
            lastUsed: new Date()
        });

        // Keep only the 5 most recent tokens per user (for multiple devices)
        user.fcmTokens = user.fcmTokens
            .sort((a, b) => b.lastUsed - a.lastUsed)
            .slice(0, 5);

        await user.save();
        console.log(`✅ FCM token updated for user ${userId}`);

        return { success: true, tokenCount: user.fcmTokens.length };
    } catch (error) {
        console.error('❌ Update FCM token error:', error.message);
        throw error;
    }
};

// BULK NOTIFICATION SENDING
export const sendBulkNotification = async (userIds, notificationData, saveToDb = true) => {
    console.log(`📤 Sending bulk notification to ${userIds.length} users`);

    const results = await Promise.allSettled(
        userIds.map(userId => sendNotification(userId, notificationData, saveToDb))
    );

    const successful = results.filter(r => r.status === 'fulfilled' && r.value).length;
    const failed = results.length - successful;

    console.log(`📊 Bulk notification results: ${successful} successful, ${failed} failed`);

    return results;
};

// USER NOTIFICATIONS RETRIEVAL
export const getUserNotifications = async (userId, limit = 50, offset = 0, unreadOnly = false) => {
    try {
        const query = { recipient: userId };
        if (unreadOnly) {
            query.isRead = false;
        }

        const [notifications, totalCount, unreadCount] = await Promise.all([
            Notification.find(query)
                // Properly populate sender, team, and task
                .populate('sender', 'name email avatar')
                .populate('team', 'name')
                .populate('task', 'name')
                // Don't populate recipient (it's the current user)
                .sort({ createdAt: -1 })
                .limit(limit)
                .skip(offset)
                .lean(), //.lean() for better performance
            Notification.countDocuments(query),
            Notification.countDocuments({ recipient: userId, isRead: false })
        ]);

        console.log(`📬 Retrieved ${notifications.length} notifications for user ${userId}`);

        return {
            notifications,
            totalCount,
            unreadCount,
            hasMore: offset + notifications.length < totalCount
        };
    } catch (error) {
        console.error('❌ Get user notifications error:', error.message);
        throw error;
    }
};

// MARK NOTIFICATION AS READ
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

        if (notification) {
            console.log(`✅ Notification ${notificationId} marked as read`);
        }

        return notification;
    } catch (error) {
        console.error('❌ Mark notification as read error:', error.message);
        throw error;
    }
};

// MARK ALL NOTIFICATIONS AS READ
export const markAllNotificationsAsRead = async (userId) => {
    try {
        const result = await Notification.updateMany(
            { recipient: userId, isRead: false },
            {
                isRead: true,
                readAt: new Date()
            }
        );

        console.log(`✅ Marked ${result.modifiedCount} notifications as read for user ${userId}`);
        return result;
    } catch (error) {
        console.error('❌ Mark all notifications as read error:', error.message);
        throw error;
    }
};

// TASK ASSIGNMENT NOTIFICATION
export const sendTaskAssignedNotification = async (taskData, assignerData, assigneeIds) => {
    try {
        if (!isFirebaseInitialized) {
            console.log('⚠️ Firebase not initialized - sending in-app notifications only');
        }

        const teamName = taskData.team?.name || 'Personal';
        const notificationData = {
            type: 'task_assigned',
            title: 'New Task Assigned',
            body: `${assignerData.name} assigned you "${taskData.name}" in ${teamName}`,
            senderId: assignerData._id,
            taskId: taskData._id,
            teamId: taskData.team?._id,
            data: {
                type: 'task_assigned',
                taskId: taskData._id.toString(),
                taskName: taskData.name,
                assignerName: assignerData.name,
                assignerId: assignerData._id.toString(),
                teamId: taskData.team?._id?.toString() || '',
                teamName: teamName,
                dueDate: taskData.dueDate?.toISOString() || '',
                priority: taskData.priority || 'medium',
                description: taskData.description || '',
                createdAt: new Date().toISOString()
            }
        };

        console.log(`📋 Sending task assignment notifications to ${assigneeIds.length} assignee(s)`);
        return await sendBulkNotification(assigneeIds, notificationData);
    } catch (error) {
        console.error('❌ Send task assigned notification error (non-critical):', error.message);
        return null;
    }
};

// TASK COMPLETION NOTIFICATION
export const sendTaskCompletedNotification = async (taskData, completerData, assignerId) => {
    try {
        const teamName = taskData.team?.name || 'Personal';
        const notificationData = {
            type: 'task_completed',
            title: 'Task Completed',
            body: `${completerData.name} completed "${taskData.name}" in ${teamName}`,
            senderId: completerData._id,
            taskId: taskData._id,
            teamId: taskData.team?._id,
            data: {
                type: 'task_completed',
                taskId: taskData._id.toString(),
                taskName: taskData.name,
                completerName: completerData.name,
                completerId: completerData._id.toString(),
                teamId: taskData.team?._id?.toString() || '',
                teamName: teamName,
                completedAt: new Date().toISOString(),
                priority: taskData.priority || 'medium'
            }
        };

        console.log(`✅ Sending task completion notification to assigner ${assignerId}`);
        return await sendNotification(assignerId, notificationData);
    } catch (error) {
        console.error('❌ Send task completed notification error (non-critical):', error.message);
        return null;
    }
};

// DUE DATE REMINDERS
export const sendDueDateReminders = async () => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);

        const nextDay = new Date(tomorrow);
        nextDay.setDate(nextDay.getDate() + 1);

        // Find tasks due tomorrow that aren't completed
        const dueTasks = await Task.find({
            dueDate: {
                $gte: tomorrow,
                $lt: nextDay
            },
            isArchived: false
        })
            .populate('assignedTo', 'name email notificationSettings')
            .populate('assignedBy', 'name email')
            .populate('team', 'name');

        console.log(`⏰ Found ${dueTasks.length} tasks due tomorrow`);

        let notificationsSent = 0;

        for (const task of dueTasks) {
            try {
                const teamName = task.team?.name || 'Personal';
                const notificationData = {
                    type: 'task_due_reminder',
                    title: 'Task Due Tomorrow',
                    body: `Don't forget: "${task.name}" in ${teamName} is due tomorrow`,
                    senderId: task.assignedBy?._id,
                    taskId: task._id,
                    teamId: task.team?._id,
                    data: {
                        type: 'task_due_reminder',
                        taskId: task._id.toString(),
                        taskName: task.name,
                        dueDate: task.dueDate.toISOString(),
                        teamName: teamName,
                        priority: task.priority || 'medium',
                        assignerName: task.assignedBy?.name || 'Unknown'
                    }
                };

                // Send to all assignees who have reminder notifications enabled
                const assigneeIds = task.assignedTo
                    .filter(user => user.notificationSettings?.taskAssigned !== false)
                    .map(user => user._id);

                if (assigneeIds.length > 0) {
                    await sendBulkNotification(assigneeIds, notificationData);
                    notificationsSent += assigneeIds.length;
                }
            } catch (taskError) {
                console.error(`❌ Error sending reminder for task ${task._id}:`, taskError.message);
            }
        }

        console.log(`✅ Sent ${notificationsSent} due date reminder notifications`);
        return notificationsSent;
    } catch (error) {
        console.error('❌ Send due date reminders error:', error.message);
        throw error;
    }
};

// CLEANUP OLD NOTIFICATIONS
export const cleanupOldNotifications = async (daysOld = 30) => {
    try {
        const cutoffDate = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);

        const result = await Notification.deleteMany({
            createdAt: { $lt: cutoffDate },
            isRead: true
        });

        console.log(`🧹 Cleaned up ${result.deletedCount} old notifications (older than ${daysOld} days)`);
        return result;
    } catch (error) {
        console.error('❌ Cleanup old notifications error:', error.message);
        throw error;
    }
};

// HEALTH CHECK FOR FIREBASE
export const checkFirebaseHealth = () => {
    return {
        initialized: isFirebaseInitialized,
        hasApps: admin.apps.length > 0,
        projectId: admin.apps.length > 0 ? admin.apps[0].options.projectId : null,
        timestamp: new Date().toISOString()
    };
};

console.log('📱 Notification Service loaded');
console.log(`🔥 Firebase status: ${isFirebaseInitialized ? 'Ready' : 'Not initialized'}`);

export default {
    sendNotification,
    sendBulkNotification,
    updateFCMToken,
    getUserNotifications,
    markNotificationAsRead,
    markAllNotificationsAsRead,
    sendTaskAssignedNotification,
    sendTaskCompletedNotification,
    sendDueDateReminders,
    cleanupOldNotifications,
    checkFirebaseHealth
};