import { Request, Response } from 'express';
import User from '../models/User';
import bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';
import { sendAccountDeletionCode } from '../services/emailService';

// Verification codes for account deletion are valid for this long.
const DELETE_ACCOUNT_CODE_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes

function generateOTP(): string {
    return randomInt(100000, 999999).toString();
}

// ── Get current user profile ──────────────────────────────────────────────

export const getProfile = async (req: Request, res: Response): Promise<void> => {
    try {
        const user = await User.findById(req.userId)
            .select('-password -emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires')
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

// ── Request account deletion (sends verification code) ────────────────────

export const requestAccountDeletion = async (req: Request, res: Response): Promise<void> => {
    try {
        const user = await User.findById(req.userId).select('+deleteAccountExpires');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }

        // Simple rate limit: block if a code was already sent recently and hasn't expired
        if (user.deleteAccountExpires) {
            const elapsed = DELETE_ACCOUNT_CODE_EXPIRY_MS - (user.deleteAccountExpires.getTime() - Date.now());
            if (elapsed < 60_000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }

        const otp = generateOTP();

        await User.findByIdAndUpdate(req.userId, {
            deleteAccountCode: otp,
            deleteAccountExpires: new Date(Date.now() + DELETE_ACCOUNT_CODE_EXPIRY_MS),
        });

        try {
            await sendAccountDeletionCode(user.email, user.name, otp);
        } catch (emailErr: any) {
            console.error('Failed to send account deletion code:', emailErr?.message ?? emailErr);
            res.status(500).json({ message: 'Failed to send verification code. Please try again.' });
            return;
        }

        res.json({ message: 'A verification code has been sent to your email.' });
    } catch (err) {
        console.error('Request account deletion error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Confirm account deletion (verifies code, deactivates account) ─────────

export const confirmAccountDeletion = async (req: Request, res: Response): Promise<void> => {
    try {
        const { code } = req.body as { code?: string };
        if (!code?.trim()) { res.status(400).json({ message: 'Verification code is required' }); return; }

        const user = await User.findById(req.userId)
            .select('+deleteAccountCode +deleteAccountExpires');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }

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

        await User.findByIdAndUpdate(req.userId, {
            isActive: false,
            deleteAccountCode: undefined,
            deleteAccountExpires: undefined,
        });

        res.json({ message: 'Account deleted successfully' });
    } catch (err) {
        console.error('Confirm account deletion error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Enable 2FA ────────────────────────────────────────────────────────────────

export const enableTwoFactor = async (req: Request, res: Response): Promise<void> => {
    try {
        const user = await User.findByIdAndUpdate(
            req.userId,
            { twoFactorEnabled: true },
            { new: true }
        ).select('-password -emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }
        res.json({ message: 'Two-factor authentication enabled', twoFactorEnabled: true });
    } catch (err) {
        console.error('Enable 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Disable 2FA ───────────────────────────────────────────────────────────────

export const disableTwoFactor = async (req: Request, res: Response): Promise<void> => {
    try {
        const user = await User.findByIdAndUpdate(
            req.userId,
            { twoFactorEnabled: false, twoFactorCode: undefined, twoFactorExpires: undefined },
            { new: true }
        ).select('-password -emailVerificationCode -emailVerificationExpires -twoFactorCode -twoFactorExpires -deleteAccountCode -deleteAccountExpires');
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }
        res.json({ message: 'Two-factor authentication disabled', twoFactorEnabled: false });
    } catch (err) {
        console.error('Disable 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};