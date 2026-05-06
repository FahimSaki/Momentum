import mongoose, { Schema } from 'mongoose';
import { ITeamDocument } from '../types/interfaces';

const teamSchema = new Schema<ITeamDocument>(
    {
        name: { type: String, required: true, trim: true },
        description: { type: String, trim: true },
        owner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        members: [
            {
                user: { type: Schema.Types.ObjectId, ref: 'User' },
                role: {
                    type: String,
                    enum: ['owner', 'admin', 'member'],
                    default: 'member',
                },
                joinedAt: { type: Date, default: Date.now },
                invitedBy: { type: Schema.Types.ObjectId, ref: 'User' },
            },
        ],
        settings: {
            allowMemberInvite: { type: Boolean, default: false },
            taskAutoDelete: { type: Boolean, default: true },
            notificationSettings: {
                taskAssigned: { type: Boolean, default: true },
                taskCompleted: { type: Boolean, default: true },
                memberJoined: { type: Boolean, default: true },
            },
        },
        isActive: { type: Boolean, default: true },
    },
    { timestamps: true }
);

teamSchema.index({ 'members.user': 1 });
teamSchema.index({ owner: 1 });

export default mongoose.model<ITeamDocument>('Team', teamSchema);