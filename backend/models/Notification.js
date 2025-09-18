import mongoose from 'mongoose';

const notificationSchema = new mongoose.Schema({
    recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    team: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' },
    task: { type: mongoose.Schema.Types.ObjectId, ref: 'Task' },
    type: {
        type: String,
        required: true,
        enum: [
            'task_assigned',
            'task_completed',
            'team_invitation',
            'team_member_joined',
            'task_due_reminder'
        ]
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    data: { type: mongoose.Schema.Types.Mixed }, // Additional data for the notification
    isRead: { type: Boolean, default: false },
    readAt: { type: Date },
    isSent: { type: Boolean, default: false }, // For FCM tracking
    fcmMessageId: { type: String } // Store FCM message ID if sent
}, { timestamps: true });

// Indexes for efficient queries
notificationSchema.index({ recipient: 1, isRead: 1 });
notificationSchema.index({ recipient: 1, createdAt: -1 });

export default mongoose.model('Notification', notificationSchema);