import { Request, Response } from 'express';
import User from '../models/User';
import bcrypt from 'bcryptjs';

// ── Get current user profile ──────────────────────────────────────────────

export const getProfile = async (req: Request, res: Response): Promise<void> => {
    try {
        const user = await User.findById(req.userId)
            .select('-password')
            .populate('teams', 'name description');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }
        res.json(user);
    } catch (err) {
        console.error('Get profile error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Update profile ────────────────────────────────────────────────────────

export const updateProfile = async (req: Request, res: Response): Promise<void> => {
    try {
        const { name, bio, timezone, avatar, isPublic, profileVisibility } = req.body;

        const update: Record<string, unknown> = {};

        if (name !== undefined) {
            const trimmedName = String(name).trim();
            if (!trimmedName) { res.status(400).json({ message: 'Name cannot be empty' }); return; }
            if (trimmedName.length > 100) { res.status(400).json({ message: 'Name must be under 100 characters' }); return; }
            update.name = trimmedName;
        }
        if (bio !== undefined) {
            update.bio = bio ? String(bio).trim().substring(0, 500) : undefined;
        }
        if (timezone !== undefined) update.timezone = String(timezone).trim();
        if (avatar !== undefined) update.avatar = avatar ? String(avatar).trim() : undefined;

        if (isPublic !== undefined) {
            if (typeof isPublic !== 'boolean') {
                res.status(400).json({ message: 'isPublic must be a boolean' }); return;
            }
            update.isPublic = isPublic;
        }

        // ── Whitelist profileVisibility keys — only allow known boolean flags ──
        // Never pass the raw object; clients could inject arbitrary nested fields.
        if (profileVisibility !== undefined &&
            profileVisibility !== null &&
            typeof profileVisibility === 'object') {
            const allowedVisibility: Record<string, boolean> = {};
            if (typeof profileVisibility.showEmail === 'boolean') allowedVisibility.showEmail = profileVisibility.showEmail;
            if (typeof profileVisibility.showName === 'boolean') allowedVisibility.showName = profileVisibility.showName;
            if (typeof profileVisibility.showBio === 'boolean') allowedVisibility.showBio = profileVisibility.showBio;
            if (Object.keys(allowedVisibility).length > 0) {
                update.profileVisibility = allowedVisibility;
            }
        }

        const user = await User.findByIdAndUpdate(
            req.userId,
            update,
            { new: true, runValidators: true }
        ).select('-password');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }

        res.json({ message: 'Profile updated successfully', user });
    } catch (err) {
        console.error('Update profile error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Update notification settings ──────────────────────────────────────────

export const updateNotificationSettings = async (req: Request, res: Response): Promise<void> => {
    try {
        const { notificationSettings } = req.body;

        const user = await User.findByIdAndUpdate(
            req.userId,
            { notificationSettings },
            { new: true, runValidators: true }
        ).select('-password');

        if (!user) { res.status(404).json({ message: 'User not found' }); return; }
        res.json({ message: 'Notification settings updated', user });
    } catch (err) {
        console.error('Update notification settings error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Register / update FCM token ───────────────────────────────────────────

export const registerFcmToken = async (req: Request, res: Response): Promise<void> => {
    console.log('📱 [FCM HIT] registerFcmToken called');
    try {
        const { token, platform = 'android' } = req.body as { token?: string; platform?: string };

        if (!token?.trim()) { res.status(400).json({ message: 'FCM token is required' }); return; }

        const user = await User.findById(req.userId);
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }

        user.fcmTokens = user.fcmTokens.filter((t) => t.token !== token);
        user.fcmTokens.push({ token, platform: platform as any, lastUsed: new Date() });
        user.fcmToken = token;

        await user.save();
        res.json({ message: 'FCM token registered successfully' });
    } catch (err) {
        console.error('Register FCM token error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Remove FCM token ──────────────────────────────────────────────────────

export const removeFcmToken = async (req: Request, res: Response): Promise<void> => {
    try {
        const { token } = req.body as { token?: string };
        if (!token) { res.status(400).json({ message: 'Token is required' }); return; }

        await User.findByIdAndUpdate(req.userId, { $pull: { fcmTokens: { token } } });
        res.json({ message: 'FCM token removed' });
    } catch (err) {
        console.error('Remove FCM token error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Find by invite ID ─────────────────────────────────────────────────────

export const findByInviteId = async (req: Request, res: Response): Promise<void> => {
    try {
        const { inviteId } = req.params;
        const user = await User.findOne({ inviteId, isPublic: true, isActive: true })
            .select('name email inviteId avatar bio profileVisibility');
        if (!user) { res.status(404).json({ message: 'User not found with that invite ID' }); return; }
        res.json(user);
    } catch (err) {
        console.error('Find by invite ID error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Search users ──────────────────────────────────────────────────────────

export const searchUsers = async (req: Request, res: Response): Promise<void> => {
    try {
        const { q = '', limit = '20' } = req.query as { q?: string; limit?: string };

        if (q.trim().length < 2) { res.json([]); return; }

        // Escape regex metacharacters to prevent ReDoS attacks
        const escaped = q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(escaped, 'i');

        const users = await User.find({
            isPublic: true,
            isActive: true,
            _id: { $ne: req.userId },
            $or: [{ name: regex }, { email: regex }, { inviteId: regex }],
        })
            .select('name email inviteId avatar bio profileVisibility')
            .limit(Math.min(parseInt(limit), 50));

        res.json(users);
    } catch (err) {
        console.error('Search users error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Change password ───────────────────────────────────────────────────────

export const changePassword = async (req: Request, res: Response): Promise<void> => {
    try {
        const { currentPassword, newPassword } = req.body as { currentPassword?: string; newPassword?: string };

        if (!currentPassword || !newPassword) { res.status(400).json({ message: 'Both passwords are required' }); return; }
        if (newPassword.length < 6) { res.status(400).json({ message: 'New password must be at least 6 characters' }); return; }

        const user = await User.findById(req.userId);
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }
        if (!user.password) { res.status(400).json({ message: 'Google accounts cannot change password here' }); return; }

        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) { res.status(400).json({ message: 'Current password is incorrect' }); return; }

        user.password = await bcrypt.hash(newPassword, 12);
        await user.save();

        res.json({ message: 'Password changed successfully' });
    } catch (err) {
        console.error('Change password error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Delete account ────────────────────────────────────────────────────────

export const deleteAccount = async (req: Request, res: Response): Promise<void> => {
    try {
        await User.findByIdAndUpdate(req.userId, { isActive: false });
        res.json({ message: 'Account deactivated successfully' });
    } catch (err) {
        console.error('Delete account error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};