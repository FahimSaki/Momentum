"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteAccount = exports.changePassword = exports.searchUsers = exports.findByInviteId = exports.removeFcmToken = exports.registerFcmToken = exports.updateNotificationSettings = exports.updateProfile = exports.getProfile = void 0;
const User_1 = __importDefault(require("../models/User"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
// ── Get current user profile ──────────────────────────────────────────────
const getProfile = async (req, res) => {
    try {
        const user = await User_1.default.findById(req.userId)
            .select('-password')
            .populate('teams', 'name description');
        if (!user) {
            res.status(404).json({ message: 'User not found' });
            return;
        }
        res.json(user);
    }
    catch (err) {
        console.error('Get profile error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.getProfile = getProfile;
// ── Update profile ────────────────────────────────────────────────────────
const updateProfile = async (req, res) => {
    try {
        const { name, bio, timezone, avatar, isPublic, profileVisibility } = req.body;
        const update = {};
        if (name !== undefined)
            update.name = name.trim();
        if (bio !== undefined)
            update.bio = bio.trim();
        if (timezone !== undefined)
            update.timezone = timezone;
        if (avatar !== undefined)
            update.avatar = avatar;
        if (isPublic !== undefined)
            update.isPublic = isPublic;
        if (profileVisibility !== undefined)
            update.profileVisibility = profileVisibility;
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
// ── Update notification settings ──────────────────────────────────────────
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
// ── Register / update FCM token ───────────────────────────────────────────
const registerFcmToken = async (req, res) => {
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
// ── Remove FCM token ──────────────────────────────────────────────────────
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
// ── Find by invite ID ─────────────────────────────────────────────────────
const findByInviteId = async (req, res) => {
    try {
        const { inviteId } = req.params;
        const user = await User_1.default.findOne({ inviteId, isPublic: true, isActive: true })
            .select('name email inviteId avatar bio profileVisibility');
        if (!user) {
            res.status(404).json({ message: 'User not found with that invite ID' });
            return;
        }
        res.json(user);
    }
    catch (err) {
        console.error('Find by invite ID error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.findByInviteId = findByInviteId;
// ── Search users ──────────────────────────────────────────────────────────
const searchUsers = async (req, res) => {
    try {
        const { q = '', limit = '20' } = req.query;
        if (q.trim().length < 2) {
            res.json([]);
            return;
        }
        const regex = new RegExp(q.trim(), 'i');
        const users = await User_1.default.find({
            isPublic: true,
            isActive: true,
            _id: { $ne: req.userId },
            $or: [{ name: regex }, { email: regex }, { inviteId: regex }],
        })
            .select('name email inviteId avatar bio profileVisibility')
            .limit(Math.min(parseInt(limit), 50));
        res.json(users);
    }
    catch (err) {
        console.error('Search users error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.searchUsers = searchUsers;
// ── Change password ───────────────────────────────────────────────────────
const changePassword = async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        if (!currentPassword || !newPassword) {
            res.status(400).json({ message: 'Both passwords are required' });
            return;
        }
        if (newPassword.length < 6) {
            res.status(400).json({ message: 'New password must be at least 6 characters' });
            return;
        }
        const user = await User_1.default.findById(req.userId);
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
        user.password = await bcryptjs_1.default.hash(newPassword, 12);
        await user.save();
        res.json({ message: 'Password changed successfully' });
    }
    catch (err) {
        console.error('Change password error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.changePassword = changePassword;
// ── Delete account ────────────────────────────────────────────────────────
const deleteAccount = async (req, res) => {
    try {
        await User_1.default.findByIdAndUpdate(req.userId, { isActive: false });
        res.json({ message: 'Account deactivated successfully' });
    }
    catch (err) {
        console.error('Delete account error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.deleteAccount = deleteAccount;
//# sourceMappingURL=userController.js.map