import mongoose, { Schema } from 'mongoose';
import { INotificationDocument, NotificationType } from '../types/interfaces';

const notificationSchema = new Schema<INotificationDocument>(
    {
        recipient: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        sender: { type: Schema.Types.ObjectId, ref: 'User' },
        team: { type: Schema.Types.ObjectId, ref: 'Team' },
        task: { type: Schema.Types.ObjectId, ref: 'Task' },
        type: {
            type: String,
            required: true,
            enum: [
                'task_assigned',
                'task_completed',
                'team_invitation',
                'team_member_joined',
                'task_due_reminder',
            ] as NotificationType[],
        },
        title: { type: String, required: true },
        message: { type: String, required: true },
        data: { type: Schema.Types.Mixed },
        isRead: { type: Boolean, default: false },
        readAt: { type: Date },
        isSent: { type: Boolean, default: false },
        fcmMessageId: { type: String },
    },
    { timestamps: true }
);

notificationSchema.index({ recipient: 1, isRead: 1 });
notificationSchema.index({ recipient: 1, createdAt: -1 });

export default mongoose.model<INotificationDocument>('Notification', notificationSchema);