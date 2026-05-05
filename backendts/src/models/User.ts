import mongoose, { Schema, Model } from 'mongoose';
import crypto from 'crypto';
import { IUserDocument, IUserModel } from '../types/interfaces';

const userSchema = new Schema<IUserDocument>(
    {
        email: { type: String, required: true, unique: true },
        password: { type: String },
        googleId: { type: String },
        name: { type: String, required: true },
        avatar: { type: String },
        bio: { type: String, maxlength: 500 },
        timezone: { type: String, default: 'UTC' },
        teams: [{ type: Schema.Types.ObjectId, ref: 'Team' }],
        notificationSettings: {
            email: { type: Boolean, default: true },
            push: { type: Boolean, default: true },
            inApp: { type: Boolean, default: true },
            taskAssigned: { type: Boolean, default: true },
            taskCompleted: { type: Boolean, default: true },
            teamInvitations: { type: Boolean, default: true },
            dailyReminder: { type: Boolean, default: false },
        },
        fcmTokens: [
            {
                token: { type: String },
                platform: { type: String, enum: ['android', 'ios', 'web', 'legacy'] },
                lastUsed: { type: Date, default: Date.now },
            },
        ],
        tasksAssigned: [{ type: Schema.Types.ObjectId, ref: 'Task' }],
        fcmToken: { type: String },
        isActive: { type: Boolean, default: true },
        lastLoginAt: { type: Date, default: Date.now },
        inviteId: {
            type: String,
            unique: true,
            required: true,
            sparse: true,
        },
        isPublic: { type: Boolean, default: true },
        profileVisibility: {
            showEmail: { type: Boolean, default: false },
            showName: { type: Boolean, default: true },
            showBio: { type: Boolean, default: true },
        },
    },
    { timestamps: true }
);

// Indexes
userSchema.index({ teams: 1 });

function generateUniqueInviteId(): string {
    const adjectives = [
        'swift', 'brave', 'wise', 'calm', 'bold', 'quick', 'smart', 'cool',
        'neat', 'fast', 'strong', 'bright', 'sharp', 'keen', 'agile', 'sleek',
        'fierce', 'noble', 'proud', 'mighty',
    ];
    const nouns = [
        'tiger', 'eagle', 'wolf', 'lion', 'hawk', 'fox', 'bear', 'shark', 'owl',
        'lynx', 'falcon', 'jaguar', 'panther', 'cobra', 'raven', 'phoenix',
        'dragon', 'viper', 'cheetah', 'leopard',
    ];
    const numbers = Math.floor(Math.random() * 9999).toString().padStart(4, '0');
    const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];
    return `${adjective}-${noun}-${numbers}`;
}

// Pre-save: generate inviteId
userSchema.pre('save', async function (next) {
    if (!this.inviteId) {
        let attempts = 0;
        const maxAttempts = 10;

        while (attempts < maxAttempts) {
            try {
                const candidateId = generateUniqueInviteId();
                const existing = await mongoose.model('User').findOne({ inviteId: candidateId });
                if (!existing) {
                    this.inviteId = candidateId;
                    console.log(`✅ Generated invite ID: ${candidateId} for ${this.email}`);
                    break;
                }
                attempts++;
            } catch (err) {
                attempts++;
            }
        }

        if (!this.inviteId) {
            const ts = Date.now().toString().slice(-6);
            this.inviteId = `user-${ts}-${Math.floor(Math.random() * 999).toString().padStart(3, '0')}`;
            console.log(`⚠️ Fallback invite ID: ${this.inviteId}`);
        }
    }

    if (!this.profileVisibility) {
        this.profileVisibility = { showEmail: false, showName: true, showBio: true };
    }

    next();
});

userSchema.post('save', function (doc: IUserDocument) {
    console.log(`✅ User saved: ${doc.email} — inviteId: ${doc.inviteId}`);
});

// Static: find by invite ID
userSchema.statics.findByInviteId = async function (inviteId: string): Promise<IUserDocument | null> {
    if (!inviteId || typeof inviteId !== 'string' || inviteId.trim().length === 0) {
        throw new Error('Invalid invite ID provided');
    }
    const user = await this.findOne({
        inviteId: inviteId.trim(),
        isPublic: true,
        isActive: true,
    }).select('name email inviteId avatar bio profileVisibility');

    if (!user) throw new Error('User not found with that invite ID');
    return user;
};

// Static: search users
userSchema.statics.searchUsers = async function (
    query: string,
    limit = 20,
    excludeUserId: string | null = null
): Promise<IUserDocument[]> {
    if (!query || query.trim().length < 2) return [];

    const searchRegex = new RegExp(query.trim(), 'i');
    const searchQuery: Record<string, unknown> = {
        isPublic: true,
        isActive: true,
        $or: [{ name: searchRegex }, { email: searchRegex }, { inviteId: searchRegex }],
    };

    if (excludeUserId) {
        searchQuery._id = { $ne: excludeUserId };
    }

    return this.find(searchQuery)
        .select('name email inviteId avatar bio profileVisibility')
        .limit(limit)
        .sort({ name: 1 });
};

type UserModel = Model<IUserDocument> & {
    findByInviteId(inviteId: string): Promise<IUserDocument | null>;
    searchUsers(query: string, limit?: number, excludeUserId?: string | null): Promise<IUserDocument[]>;
};

export default mongoose.model<IUserDocument, UserModel>('User', userSchema);