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

    // FIXED: Invite id generation with better error handling
    inviteId: {
        type: String,
        unique: true,
        required: true,
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
// Remove this line since inviteId already has unique: true in schema definition
// userSchema.index({ inviteId: 1 }, { unique: true, sparse: true });

// ENHANCED HELPER FUNCTION with better uniqueness checking
function generateUniqueInviteId() {
    const adjectives = [
        'swift', 'brave', 'wise', 'calm', 'bold', 'quick', 'smart', 'cool', 'neat', 'fast',
        'strong', 'bright', 'sharp', 'keen', 'agile', 'sleek', 'fierce', 'noble', 'proud', 'mighty'
    ];
    const nouns = [
        'tiger', 'eagle', 'wolf', 'lion', 'hawk', 'fox', 'bear', 'shark', 'owl', 'lynx',
        'falcon', 'jaguar', 'panther', 'cobra', 'raven', 'phoenix', 'dragon', 'viper', 'cheetah', 'leopard'
    ];
    const numbers = Math.floor(Math.random() * 9999).toString().padStart(4, '0');

    const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];

    return `${adjective}-${noun}-${numbers}`;
}

// ENHANCED pre-save middleware with better error handling
userSchema.pre('save', async function (next) {
    // Only generate inviteId if it doesn't exist
    if (!this.inviteId) {
        let attempts = 0;
        const maxAttempts = 10;

        while (attempts < maxAttempts) {
            try {
                const candidateId = generateUniqueInviteId();

                // Check if this ID already exists
                const existingUser = await mongoose.model('User').findOne({ inviteId: candidateId });

                if (!existingUser) {
                    this.inviteId = candidateId;
                    console.log(`✅ Generated unique invite ID: ${candidateId} for user: ${this.email}`);
                    break;
                }

                attempts++;
                console.log(`⚠️ Invite ID collision detected (${candidateId}), retrying... (${attempts}/${maxAttempts})`);

            } catch (error) {
                console.error('Error generating invite ID:', error);
                attempts++;
            }
        }

        if (!this.inviteId) {
            // Fallback to timestamp-based ID if we can't generate a unique one
            const timestamp = Date.now().toString().slice(-6);
            this.inviteId = `user-${timestamp}-${Math.floor(Math.random() * 999).toString().padStart(3, '0')}`;
            console.log(`⚠️ Using fallback invite ID: ${this.inviteId} for user: ${this.email}`);
        }
    }

    // Ensure profileVisibility exists
    if (!this.profileVisibility) {
        this.profileVisibility = {
            showEmail: false,
            showName: true,
            showBio: true
        };
    }

    next();
});

// ENHANCED post-save middleware for logging
userSchema.post('save', function (doc, next) {
    console.log(`✅ User saved: ${doc.email} with invite ID: ${doc.inviteId}`);
    next();
});

// ENHANCED error handling for duplicate keys
userSchema.post('save', function (error, doc, next) {
    if (error.name === 'MongoError' && error.code === 11000) {
        if (error.message.includes('inviteId')) {
            console.log('⚠️ Invite ID collision during save, will retry...');
            // Clear the inviteId to trigger regeneration
            doc.inviteId = undefined;
            return doc.save();
        }
    }
    next(error);
});

// STATIC METHOD to find user by invite ID with better error handling
userSchema.statics.findByInviteId = async function (inviteId) {
    try {
        if (!inviteId || typeof inviteId !== 'string' || inviteId.trim().length === 0) {
            throw new Error('Invalid invite ID provided');
        }

        const user = await this.findOne({
            inviteId: inviteId.trim(),
            isPublic: true,
            isActive: true
        }).select('name email inviteId avatar bio profileVisibility');

        if (!user) {
            throw new Error('User not found with that invite ID');
        }

        return user;
    } catch (error) {
        console.error('Error finding user by invite ID:', error);
        throw error;
    }
};

// STATIC METHOD to search users with better filtering
userSchema.statics.searchUsers = async function (query, limit = 20, excludeUserId = null) {
    try {
        if (!query || typeof query !== 'string' || query.trim().length < 2) {
            return [];
        }

        const searchRegex = new RegExp(query.trim(), 'i');
        const searchQuery = {
            isPublic: true,
            isActive: true,
            $or: [
                { name: searchRegex },
                { email: searchRegex },
                { inviteId: searchRegex }
            ]
        };

        if (excludeUserId) {
            searchQuery._id = { $ne: excludeUserId };
        }

        const users = await this.find(searchQuery)
            .select('name email inviteId avatar bio profileVisibility')
            .limit(parseInt(limit))
            .sort({ name: 1 });

        console.log(`🔍 User search for "${query}" returned ${users.length} results`);
        return users;
    } catch (error) {
        console.error('Error searching users:', error);
        throw error;
    }
};

export default mongoose.model('User', userSchema);