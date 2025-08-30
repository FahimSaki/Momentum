import mongoose from 'mongoose';

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
    lastLoginAt: { type: Date, default: Date.now }
}, { timestamps: true });

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ teams: 1 });

export default mongoose.model('User', userSchema);