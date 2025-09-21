import mongoose from 'mongoose';
import crypto from 'crypto';

const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String }, // Not required for Google users
    googleId: { type: String },
    name: { type: String, required: true },

    // Profile enhancements
    avatar: { type: String }, // URL to profile picture
    bio: { type: String, maxlength: 500 },
    timezone: { type: String, default: 'UTC' },

    // Team memberships
    teams: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Team' }],

    // Notification preferences
    notificationSettings: {
        email: { type: Boolean, default: true },
        push: { type: Boolean, default: true },
        inApp: { type: Boolean, default: true },
        taskAssigned: { type: Boolean, default: true },
        taskCompleted: { type: Boolean, default: true },
        teamInvitations: { type: Boolean, default: true },
        dailyReminder: { type: Boolean, default: false }
    },

    // FCM tokens for push notifications
    fcmTokens: [{
        token: { type: String },
        platform: { type: String, enum: ['android', 'ios', 'web'] },
        lastUsed: { type: Date, default: Date.now }
    }],

    // Legacy fields (keep for backward compatibility)
    tasksAssigned: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Task' }],
    fcmToken: { type: String }, // Keep for backward compatibility

    // Account status
    isActive: { type: Boolean, default: true },
    lastLoginAt: { type: Date, default: Date.now },

    // Invite id generation
    inviteId: {
        type: String,
        unique: true,
        required: true,
        index: true,
        sparse: true // Handle existing users without inviteId
    },
    isPublic: {
        type: Boolean,
        default: true
    },
    profileVisibility: {
        showEmail: { type: Boolean, default: false },
        showName: { type: Boolean, default: true },
        showBio: { type: Boolean, default: true }
    }
}, { timestamps: true });

// Indexes
userSchema.index({ teams: 1 });

// HELPER FUNCTION - Add this before export
function generateUniqueInviteId() {
    const adjectives = ['swift', 'brave', 'wise', 'calm', 'bold', 'quick', 'smart', 'cool', 'neat', 'fast'];
    const nouns = ['tiger', 'eagle', 'wolf', 'lion', 'hawk', 'fox', 'bear', 'shark', 'owl', 'lynx'];
    const numbers = Math.floor(Math.random() * 9999).toString().padStart(4, '0');

    return `${adjectives[Math.floor(Math.random() * adjectives.length)]}-${nouns[Math.floor(Math.random() * nouns.length)]}-${numbers}`;
}

// Pre-save middleware to generate unique inviteId
userSchema.pre('save', async function (next) {
    if (!this.inviteId) {
        let isUnique = false;
        while (!isUnique) {
            const candidateId = generateUniqueInviteId();
            const existingUser = await mongoose.model('User').findOne({ inviteId: candidateId });
            if (!existingUser) {
                this.inviteId = candidateId;
                isUnique = true;
            }
        }
    }
    next();
});

export default mongoose.model('User', userSchema);
