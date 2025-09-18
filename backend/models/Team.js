import mongoose from 'mongoose';

const teamSchema = new mongoose.Schema({
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    members: [{
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        role: {
            type: String,
            enum: ['owner', 'admin', 'member'],
            default: 'member'
        },
        joinedAt: { type: Date, default: Date.now },
        invitedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
    }],
    settings: {
        allowMemberInvite: { type: Boolean, default: false },
        taskAutoDelete: { type: Boolean, default: true },
        notificationSettings: {
            taskAssigned: { type: Boolean, default: true },
            taskCompleted: { type: Boolean, default: true },
            memberJoined: { type: Boolean, default: true }
        }
    },
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

// Index for efficient queries
teamSchema.index({ 'members.user': 1 });
teamSchema.index({ owner: 1 });

export default mongoose.model('Team', teamSchema);