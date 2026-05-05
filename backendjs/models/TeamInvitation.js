import mongoose from 'mongoose';

const teamInvitationSchema = new mongoose.Schema({
    team: { type: mongoose.Schema.Types.ObjectId, ref: 'Team', required: true },
    inviter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    invitee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    email: { type: String, required: true }, // Store email in case user doesn't exist yet
    role: { type: String, enum: ['admin', 'member'], default: 'member' },
    status: {
        type: String,
        enum: ['pending', 'accepted', 'declined', 'expired'],
        default: 'pending'
    },
    expiresAt: {
        type: Date,
        default: () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
    },
    message: { type: String, trim: true }
}, { timestamps: true });

// Compound index to prevent duplicate invitations
teamInvitationSchema.index({ team: 1, invitee: 1, status: 1 }, { unique: true });

export default mongoose.model('TeamInvitation', teamInvitationSchema);