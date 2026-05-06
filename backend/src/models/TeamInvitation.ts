import mongoose, { Schema } from 'mongoose';
import { ITeamInvitationDocument } from '../types/interfaces';

const teamInvitationSchema = new Schema<ITeamInvitationDocument>(
    {
        team: { type: Schema.Types.ObjectId, ref: 'Team', required: true },
        inviter: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        invitee: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        email: { type: String, required: true },
        role: { type: String, enum: ['admin', 'member'], default: 'member' },
        status: {
            type: String,
            enum: ['pending', 'accepted', 'declined', 'expired'],
            default: 'pending',
        },
        expiresAt: {
            type: Date,
            default: () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
        message: { type: String, trim: true },
    },
    { timestamps: true }
);

teamInvitationSchema.index({ team: 1, invitee: 1, status: 1 }, { unique: true });

export default mongoose.model<ITeamInvitationDocument>('TeamInvitation', teamInvitationSchema);