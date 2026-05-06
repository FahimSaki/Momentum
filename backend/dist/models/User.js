"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importStar(require("mongoose"));
const userSchema = new mongoose_1.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String },
    googleId: { type: String },
    name: { type: String, required: true },
    avatar: { type: String },
    bio: { type: String, maxlength: 500 },
    timezone: { type: String, default: 'UTC' },
    teams: [{ type: mongoose_1.Schema.Types.ObjectId, ref: 'Team' }],
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
    tasksAssigned: [{ type: mongoose_1.Schema.Types.ObjectId, ref: 'Task' }],
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
}, { timestamps: true });
// ── Indexes ─────────────────────────────────────────────
userSchema.index({ teams: 1 });
// ── Invite ID Generator ────────────────────────────────
function generateUniqueInviteId() {
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
userSchema.pre('save', async function (next) {
    if (!this.inviteId) {
        let attempts = 0;
        const maxAttempts = 10;
        while (attempts < maxAttempts) {
            try {
                const candidateId = generateUniqueInviteId();
                const existing = await mongoose_1.default
                    .model('User')
                    .findOne({ inviteId: candidateId });
                if (!existing) {
                    this.inviteId = candidateId;
                    break;
                }
                attempts++;
            }
            catch {
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
exports.default = mongoose_1.default.model('User', userSchema);
//# sourceMappingURL=User.js.map