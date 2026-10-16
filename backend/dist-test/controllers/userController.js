"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.disableTwoFactor = exports.enableTwoFactor = exports.confirmAccountDeletion = exports.requestAccountDeletion = exports.confirmPasswordChange = exports.requestPasswordChange = exports.searchUsers = exports.findByInviteId = exports.removeFcmToken = exports.registerFcmToken = exports.updateNotificationSettings = exports.updateProfile = exports.getProfile = void 0;
const User_1 = __importDefault(require("../models/User"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const emailService_1 = require("../services/emailService");
const otpService_1 = require("../services/otpService");
// Verification codes for account deletion are valid for this long.
const DELETE_ACCOUNT_CODE_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
const PASSWORD_CHANGE_CODE_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
// Get current user profile 
const getProfile = async (req, res) => {
    try {
        const user = await User_1.default.findById(req.userId)
            .select('-emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires -passwordResetCode -passwordResetExpires -passwordChangeCode -passwordChangeExpires')
            .populate('teams', 'name description');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        // password is intentionally still selected above so we can derive
        // hasPassword — it's stripped before the response goes out below.
        const userObj = user.toObject();
        const hasPassword = !!userObj.password;
        delete userObj.password;
        res.json({ ...userObj, hasPassword });
    }
    catch (err) {
        console.error('Get profile error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getProfile = getProfile;
// Update profile 
const updateProfile = async (req, res) => {
    try {
        const { name, bio, timezone, avatar, isPublic, profileVisibility } = req.body;
        const update = {};
        if (name !== undefined) {
            const trimmedName = String(name).trim();
            if (!trimmedName) {
                res.status(400).json({ message: 'Name cannot be empty' });
                return;
            }
            if (trimmedName.length > 100) {
                res.status(400).json({ message: 'Name must be under 100 characters' });
                return;
            }
            update.name = trimmedName;
        }
        if (bio !== undefined) {
            update.bio = bio ? String(bio).trim().substring(0, 500) : undefined;
        }
        if (timezone !== undefined)
            update.timezone = String(timezone).trim();
        if (avatar !== undefined)
            update.avatar = avatar ? String(avatar).trim() : undefined;
        if (isPublic !== undefined) {
            if (typeof isPublic !== 'boolean') {
                res.status(400).json({ message: 'isPublic must be a boolean' });
                return;
            }
            update.isPublic = isPublic;
        }
        // Whitelist profileVisibility keys — only allow known boolean flags
        // Never pass the raw object; clients could inject arbitrary nested fields.
        if (profileVisibility !== undefined &&
            profileVisibility !== null &&
            typeof profileVisibility === 'object') {
            const allowedVisibility = {};
            if (typeof profileVisibility.showEmail === 'boolean')
                allowedVisibility.showEmail = profileVisibility.showEmail;
            if (typeof profileVisibility.showName === 'boolean')
                allowedVisibility.showName = profileVisibility.showName;
            if (typeof profileVisibility.showBio === 'boolean')
                allowedVisibility.showBio = profileVisibility.showBio;
            if (Object.keys(allowedVisibility).length > 0) {
                update.profileVisibility = allowedVisibility;
            }
        }
        const user = await User_1.default.findByIdAndUpdate(req.userId, update, { new: true, runValidators: true }).select('-password');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        res.json({ message: 'Profile updated successfully', user });
    }
    catch (err) {
        console.error('Update profile error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.updateProfile = updateProfile;
// Update notification settings 
const updateNotificationSettings = async (req, res) => {
    try {
        const { notificationSettings } = req.body;
        const user = await User_1.default.findByIdAndUpdate(req.userId, { notificationSettings }, { new: true, runValidators: true }).select('-password');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        res.json({ message: 'Notification settings updated', user });
    }
    catch (err) {
        console.error('Update notification settings error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.updateNotificationSettings = updateNotificationSettings;
// Register / update FCM token 
const registerFcmToken = async (req, res) => {
    console.log('📱 [FCM HIT] registerFcmToken called');
    try {
        const { token, platform = 'android' } = req.body;
        if (!token?.trim()) {
            res.status(400).json({ message: 'FCM token is required' });
            return;
        }
        const user = await User_1.default.findById(req.userId);
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        user.fcmTokens = user.fcmTokens.filter((t) => t.token !== token);
        user.fcmTokens.push({ token, platform: platform, lastUsed: new Date() });
        user.fcmToken = token;
        await user.save();
        res.json({ message: 'FCM token registered successfully' });
    }
    catch (err) {
        console.error('Register FCM token error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.registerFcmToken = registerFcmToken;
// Remove FCM token 
const removeFcmToken = async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) {
            res.status(400).json({ message: 'Token is required' });
            return;
        }
        await User_1.default.findByIdAndUpdate(req.userId, { $pull: { fcmTokens: { token } } });
        res.json({ message: 'FCM token removed' });
    }
    catch (err) {
        console.error('Remove FCM token error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.removeFcmToken = removeFcmToken;
// Public profile (what other users may see) 
const PRIVATE_NAME = 'Private user';
const PUBLIC_PROFILE_FIELDS = 'name email inviteId avatar bio profileVisibility';
/** The invite ID and avatar are always visible. Name, email and bio follow the
 *  owner's profileVisibility flags; a hidden name is replaced by a placeholder
 *  and hidden email/bio are left out of the response entirely. Defaults match
 *  the schema: showName true, showEmail false, showBio true. */
const toPublicProfile = (user) => {
    const visibility = user.profileVisibility;
    return {
        _id: user._id,
        inviteId: user.inviteId,
        avatar: user.avatar,
        name: visibility?.showName === false ? PRIVATE_NAME : user.name,
        email: visibility?.showEmail === true ? user.email : undefined,
        bio: visibility?.showBio === false ? undefined : user.bio,
        profileVisibility: visibility,
    };
};
// Find by invite ID 
const findByInviteId = async (req, res) => {
    try {
        const { inviteId } = req.params;
        const user = await User_1.default.findOne({ inviteId, isPublic: true, isActive: true })
            .select(PUBLIC_PROFILE_FIELDS);
        if (!user) {
            res.status(404).json({ message: 'User not found with that invite ID' });
            return;
        }
        res.json(toPublicProfile(user));
    }
    catch (err) {
        console.error('Find by invite ID error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.findByInviteId = findByInviteId;
// Search users 
const searchUsers = async (req, res) => {
    try {
        const { q = '', limit = '20' } = req.query;
        if (q.trim().length < 2) {
            res.json([]);
            return;
        }
        // Escape regex metacharacters to prevent ReDoS attacks
        const escaped = q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(escaped, 'i');
        // The invite ID is always searchable. Name and email only match users
        // who allow them to be seen, otherwise a search would confirm a value
        // the owner chose to hide.
        const users = await User_1.default.find({
            isPublic: true,
            isActive: true,
            _id: { $ne: req.userId },
            $or: [
                { inviteId: regex },
                { name: regex, 'profileVisibility.showName': { $ne: false } },
                { email: regex, 'profileVisibility.showEmail': true },
            ],
        })
            .select(PUBLIC_PROFILE_FIELDS)
            .limit(Math.min(parseInt(limit), 50));
        res.json(users.map((u) => toPublicProfile(u)));
    }
    catch (err) {
        console.error('Search users error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.searchUsers = searchUsers;
// Request password change (step 1: verify current password, send OTP)
const requestPasswordChange = async (req, res) => {
    try {
        const { currentPassword } = req.body;
        if (!currentPassword) {
            res.status(400).json({ message: 'Current password is required' });
            return;
        }
        const user = await User_1.default.findById(req.userId).select('+passwordChangeExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        if (!user.password) {
            res.status(400).json({ message: 'Google accounts cannot change password here' });
            return;
        }
        const isMatch = await bcryptjs_1.default.compare(currentPassword, user.password);
        if (!isMatch) {
            res.status(400).json({ message: 'Current password is incorrect' });
            return;
        }
        // Simple rate limit: block if a code was already sent recently and hasn't expired
        if (user.passwordChangeExpires) {
            const elapsed = PASSWORD_CHANGE_CODE_EXPIRY_MS - (user.passwordChangeExpires.getTime() - Date.now());
            if (elapsed < 60000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }
        const { sent } = await (0, otpService_1.generateAndSendOtp)({
            persist: async (code, expiresAt) => {
                await User_1.default.findByIdAndUpdate(req.userId, {
                    passwordChangeCode: code,
                    passwordChangeExpires: expiresAt,
                });
            },
            send: (code) => (0, emailService_1.sendPasswordChangeCode)(user.email, user.name, code),
            expiryMs: PASSWORD_CHANGE_CODE_EXPIRY_MS,
            logContext: `${user.email} (password change)`,
        });
        if (!sent) {
            res.status(500).json({ message: 'Failed to send verification code. Please try again.' });
            return;
        }
        res.json({ message: 'A verification code has been sent to your email.' });
    }
    catch (err) {
        console.error('Request password change error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.requestPasswordChange = requestPasswordChange;
// Confirm password change (step 2: verify OTP, apply new password) 
const confirmPasswordChange = async (req, res) => {
    try {
        const { code, newPassword } = req.body;
        if (!code?.trim()) {
            res.status(400).json({ message: 'Verification code is required' });
            return;
        }
        if (!newPassword || newPassword.length < 6) {
            res.status(400).json({ message: 'New password must be at least 6 characters' });
            return;
        }
        const user = await User_1.default.findById(req.userId).select('+passwordChangeCode +passwordChangeExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        if (!user.passwordChangeCode || !user.passwordChangeExpires) {
            res.status(400).json({ message: 'No verification code found. Please request a new one.' });
            return;
        }
        if (new Date() > user.passwordChangeExpires) {
            res.status(400).json({ message: 'Verification code expired. Please request a new one.' });
            return;
        }
        if (user.passwordChangeCode !== code.trim()) {
            res.status(400).json({ message: 'Invalid verification code' });
            return;
        }
        user.password = await bcryptjs_1.default.hash(newPassword, 12);
        user.passwordChangeCode = undefined;
        user.passwordChangeExpires = undefined;
        await user.save();
        res.json({ message: 'Password changed successfully' });
    }
    catch (err) {
        console.error('Confirm password change error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.confirmPasswordChange = confirmPasswordChange;
// Request account deletion (sends verification code) 
const requestAccountDeletion = async (req, res) => {
    try {
        const user = await User_1.default.findById(req.userId).select('+deleteAccountExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        // Simple rate limit: block if a code was already sent recently and hasn't expired
        if (user.deleteAccountExpires) {
            const elapsed = DELETE_ACCOUNT_CODE_EXPIRY_MS - (user.deleteAccountExpires.getTime() - Date.now());
            if (elapsed < 60000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }
        const { sent } = await (0, otpService_1.generateAndSendOtp)({
            persist: async (code, expiresAt) => {
                await User_1.default.findByIdAndUpdate(req.userId, {
                    deleteAccountCode: code,
                    deleteAccountExpires: expiresAt,
                });
            },
            send: (code) => (0, emailService_1.sendAccountDeletionCode)(user.email, user.name, code),
            expiryMs: DELETE_ACCOUNT_CODE_EXPIRY_MS,
            logContext: `${user.email} (account deletion)`,
        });
        if (!sent) {
            res.status(500).json({ message: 'Failed to send verification code. Please try again.' });
            return;
        }
        res.json({ message: 'A verification code has been sent to your email.' });
    }
    catch (err) {
        console.error('Request account deletion error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.requestAccountDeletion = requestAccountDeletion;
// Confirm account deletion (verifies code, deactivates account)
const confirmAccountDeletion = async (req, res) => {
    try {
        const { code } = req.body;
        if (!code?.trim()) {
            res.status(400).json({ message: 'Verification code is required' });
            return;
        }
        const user = await User_1.default.findById(req.userId)
            .select('+deleteAccountCode +deleteAccountExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        if (!user.deleteAccountCode || !user.deleteAccountExpires) {
            res.status(400).json({ message: 'No verification code found. Please request a new one.' });
            return;
        }
        if (new Date() > user.deleteAccountExpires) {
            res.status(400).json({ message: 'Verification code expired. Please request a new one.' });
            return;
        }
        if (user.deleteAccountCode !== code.trim()) {
            res.status(400).json({ message: 'Invalid verification code' });
            return;
        }
        await User_1.default.findByIdAndUpdate(req.userId, {
            isActive: false,
            deleteAccountCode: undefined,
            deleteAccountExpires: undefined,
        });
        res.json({ message: 'Account deleted successfully' });
    }
    catch (err) {
        console.error('Confirm account deletion error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.confirmAccountDeletion = confirmAccountDeletion;
// Enable 2FA 
const enableTwoFactor = async (req, res) => {
    try {
        const user = await User_1.default.findByIdAndUpdate(req.userId, { twoFactorEnabled: true }, { new: true }).select('-password -emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        res.json({ message: 'Two-factor authentication enabled', twoFactorEnabled: true });
    }
    catch (err) {
        console.error('Enable 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.enableTwoFactor = enableTwoFactor;
// Disable 2FA 
const disableTwoFactor = async (req, res) => {
    try {
        const user = await User_1.default.findByIdAndUpdate(req.userId, { twoFactorEnabled: false, twoFactorCode: undefined, twoFactorExpires: undefined }, { new: true }).select('-password -emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        res.json({ message: 'Two-factor authentication disabled', twoFactorEnabled: false });
    }
    catch (err) {
        console.error('Disable 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.disableTwoFactor = disableTwoFactor;
