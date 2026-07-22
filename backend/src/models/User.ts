import mongoose, { Schema, Model } from 'mongoose';
import { IUserDocument } from '../types/interfaces';

const userSchema = new Schema<IUserDocument>(
    {
        email: { type: String, required: true, unique: true },
        password: { type: String },
        googleId: { type: String },
        isEmailVerified: { type: Boolean, default: false },
        emailVerificationCode: { type: String, select: false },
        emailVerificationExpires: { type: Date, select: false },
        twoFactorEnabled: { type: Boolean, default: false },
        twoFactorCode: { type: String, select: false },
        twoFactorExpires: { type: Date, select: false },
        deleteAccountCode: { type: String, select: false },
        deleteAccountExpires: { type: Date, select: false },
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
            required: false,
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

// ── Indexes ─────────────────────────────────────────────
userSchema.index({ teams: 1 });

// ── Invite ID Generator ────────────────────────────────
function generateUniqueInviteId(): string {
    const adjectives = [
        'swift', 'brave', 'wise', 'calm', 'bold', 'quick', 'smart', 'cool', 'neat', 'fast',
        'strong', 'bright', 'sharp', 'keen', 'agile', 'sleek', 'fierce', 'noble', 'proud', 'mighty'
    ];

    const nouns = [
        'tiger', 'eagle', 'wolf', 'lion', 'hawk', 'fox', 'bear', 'shark', 'owl', 'lynx',
        'falcon', 'jaguar', 'panther', 'cobra', 'raven', 'phoenix', 'dragon', 'viper', 'cheetah', 'leopard'
    ];

    const numbers = Math.floor(Math.random() * 9999)
        .toString()
        .padStart(4, '0');

    const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
    const noun = nouns[Math.floor(Math.random() * nouns.length)];

    return `${adjective}-${noun}-${numbers}`;
}

// ── Pre-save hook ───────────────────────────────────────
userSchema.pre('validate', async function (next) {
    if (!this.inviteId) {
        let attempts = 0;
        const maxAttempts = 10;

        while (attempts < maxAttempts) {
            try {
                const candidateId = generateUniqueInviteId();
                const existing = await mongoose
                    .model('User')
                    .findOne({ inviteId: candidateId });

                if (!existing) {
                    this.inviteId = candidateId;
                    break;
                }

                attempts++;
            } catch {
                attempts++;
            }
        }

        if (!this.inviteId) {
            const ts = Date.now().toString().slice(-6);
            this.inviteId = `user-${ts}-${Math.floor(Math.random() * 999).toString().padStart(3, '0')}`;
        }
    }

    if (!this.profileVisibility) {
        this.profileVisibility = {
            showEmail: false,
            showName: true,
            showBio: true,
        };
    }

    next();
});

// ── Post-save log ───────────────────────────────────────
userSchema.post('save', function (doc) {
    console.log(`✅ User saved: ${doc.email} — inviteId: ${doc.inviteId}`);
});

// ── Static methods typing ───────────────────────────────
type UserModel = Model<IUserDocument> & {
    findByInviteId(inviteId: string): Promise<IUserDocument | null>;
    searchUsers(
        query: string,
        limit?: number,
        excludeUserId?: string | null
    ): Promise<IUserDocument[]>;
};

export default mongoose.model<IUserDocument, UserModel>(
    'User',
    userSchema
);