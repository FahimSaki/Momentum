import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { randomInt } from 'crypto';
import User from '../models/User';
import { sendVerificationEmail, send2FACode } from '../services/emailService';

function generateOTP(): string {
    return randomInt(100000, 999999).toString();
}

function buildUserResponse(user: any) {
    return {
        _id: user._id,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        bio: user.bio,
        timezone: user.timezone,
        teams: user.teams,
        notificationSettings: user.notificationSettings,
        isActive: user.isActive,
        lastLoginAt: user.lastLoginAt,
        inviteId: user.inviteId,
        isPublic: user.isPublic,
        profileVisibility: user.profileVisibility,
        isEmailVerified: user.isEmailVerified,
        twoFactorEnabled: user.twoFactorEnabled,
    };
}

// ── Register ──────────────────────────────────────────────────────────────────

export const register = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, password, name } = req.body as {
            email?: string; password?: string; name?: string;
        };

        if (!email?.trim()) { res.status(400).json({ message: 'Email is required' }); return; }
        if (!password || password.length < 6) { res.status(400).json({ message: 'Password must be at least 6 characters' }); return; }
        if (!name?.trim()) { res.status(400).json({ message: 'Name is required' }); return; }

        const trimmedEmail = email.toLowerCase().trim();
        const existing = await User.findOne({ email: trimmedEmail });
        if (existing) {
            res.status(400).json({ message: 'An account with this email already exists. Please login instead.' });
            return;
        }

        const hashedPassword = await bcrypt.hash(password, 12);
        const otp = generateOTP();

        const user = new User({
            email: trimmedEmail,
            password: hashedPassword,
            name: name.trim(),
            isEmailVerified: false,
            emailVerificationCode: otp,
            emailVerificationExpires: new Date(Date.now() + 24 * 60 * 60 * 1000),
            twoFactorEnabled: false,
            isActive: true,
            lastLoginAt: new Date(),
            notificationSettings: {
                email: true, push: true, inApp: true,
                taskAssigned: true, taskCompleted: true,
                teamInvitations: true, dailyReminder: false,
            },
        });

        await user.save();

        // Await the email so any failure is visible in Railway logs immediately.
        // The account is already created — user can request resend if this fails.
        try {
            await sendVerificationEmail(trimmedEmail, name.trim(), otp);
            console.log(`✅ Verification email sent to ${trimmedEmail}`);
        } catch (emailErr: any) {
            console.error(`❌ Failed to send verification email to ${trimmedEmail}:`, emailErr?.message ?? emailErr);
            // Still return 201 — account exists and user can use "Resend" to get the code
        }

        res.status(201).json({
            message: 'Account created. Check your email for a 6-digit verification code.',
            requiresVerification: true,
            email: trimmedEmail,
        });
    } catch (err: any) {
        console.error('Register error:', err);
        if (err.code === 11000) { res.status(400).json({ message: 'An account with this email already exists' }); return; }
        res.status(500).json({ message: 'Server error during registration' });
    }
};

// ── Verify email OTP ──────────────────────────────────────────────────────────

export const verifyEmail = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, code } = req.body as { email?: string; code?: string };
        if (!email || !code) { res.status(400).json({ message: 'Email and code are required' }); return; }

        const user = await User.findOne({ email: email.toLowerCase().trim() })
            .select('+emailVerificationCode +emailVerificationExpires');

        if (!user) { res.status(404).json({ message: 'Account not found' }); return; }
        if (user.isEmailVerified) { res.json({ message: 'Email already verified' }); return; }

        if (!user.emailVerificationCode || !user.emailVerificationExpires) {
            res.status(400).json({ message: 'No verification code found. Request a new one.' });
            return;
        }
        if (new Date() > user.emailVerificationExpires) {
            res.status(400).json({ message: 'Verification code expired. Request a new one.' });
            return;
        }
        if (user.emailVerificationCode !== code.trim()) {
            res.status(400).json({ message: 'Invalid verification code' });
            return;
        }

        user.isEmailVerified = true;
        user.emailVerificationCode = undefined;
        user.emailVerificationExpires = undefined;
        await user.save();

        res.json({ message: 'Email verified successfully. You can now log in.' });
    } catch (err) {
        console.error('Verify email error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Resend verification code ──────────────────────────────────────────────────

export const resendVerification = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email } = req.body as { email?: string };
        if (!email) { res.status(400).json({ message: 'Email is required' }); return; }

        const user = await User.findOne({ email: email.toLowerCase().trim() })
            .select('+emailVerificationExpires');

        if (!user) { res.status(404).json({ message: 'Account not found' }); return; }
        if (user.isEmailVerified) { res.json({ message: 'Email is already verified' }); return; }

        // Simple rate limit: block if a code was sent in the last 60 seconds
        if (user.emailVerificationExpires) {
            const elapsed = (24 * 60 * 60 * 1000) - (user.emailVerificationExpires.getTime() - Date.now());
            if (elapsed < 60_000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }

        const otp = generateOTP();
        await User.findByIdAndUpdate(user._id, {
            emailVerificationCode: otp,
            emailVerificationExpires: new Date(Date.now() + 24 * 60 * 60 * 1000),
        });

        // Await so the client gets a real error if the email service is down
        try {
            await sendVerificationEmail(user.email, user.name, otp);
            console.log(`✅ Verification email resent to ${user.email}`);
            res.json({ message: 'Verification code sent to your email.' });
        } catch (emailErr: any) {
            console.error(`❌ Failed to resend verification email to ${user.email}:`, emailErr?.message ?? emailErr);
            res.status(500).json({ message: 'Failed to send verification code. Check server logs for details.' });
        }
    } catch (err) {
        console.error('Resend verification error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Login ─────────────────────────────────────────────────────────────────────

export const login = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, password } = req.body as { email?: string; password?: string };
        if (!email || !password) { res.status(400).json({ message: 'Email and password are required' }); return; }

        const trimmedEmail = email.toLowerCase().trim();
        const user = await User.findOne({ email: trimmedEmail })
            .select('+emailVerificationCode +emailVerificationExpires +twoFactorCode +twoFactorExpires');

        if (!user) { res.status(401).json({ message: 'Invalid email or password' }); return; }

        if (!user.password) {
            res.status(401).json({ message: 'This account uses Google Sign-In. Please use the Google button.' });
            return;
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) { res.status(401).json({ message: 'Invalid email or password' }); return; }

        // Block unverified accounts and auto-resend code
        if (!user.isEmailVerified) {
            const otp = generateOTP();
            await User.findByIdAndUpdate(user._id, {
                emailVerificationCode: otp,
                emailVerificationExpires: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
            try {
                await sendVerificationEmail(user.email, user.name, otp);
                console.log(`✅ Verification email (re)sent to ${user.email} on login attempt`);
            } catch (emailErr: any) {
                console.error(`❌ Failed to send verification email on login to ${user.email}:`, emailErr?.message ?? emailErr);
            }

            res.status(403).json({
                message: 'Please verify your email first. A new code has been sent.',
                requiresVerification: true,
                email: user.email,
            });
            return;
        }

        // 2FA challenge
        if (user.twoFactorEnabled) {
            const otp = generateOTP();
            await User.findByIdAndUpdate(user._id, {
                twoFactorCode: otp,
                twoFactorExpires: new Date(Date.now() + 10 * 60 * 1000),
            });

            // Await the 2FA email — if this fails the user is completely stuck,
            // so we must surface the error rather than pretending it was sent.
            try {
                await send2FACode(user.email, user.name, otp);
                console.log(`✅ 2FA code sent to ${user.email}`);
            } catch (emailErr: any) {
                console.error(`❌ Failed to send 2FA code to ${user.email}:`, emailErr?.message ?? emailErr);
                // Clear the code so user can attempt login again later
                await User.findByIdAndUpdate(user._id, {
                    twoFactorCode: undefined,
                    twoFactorExpires: undefined,
                });
                res.status(500).json({
                    message: 'Failed to send verification code. Please try again or disable 2FA in settings.',
                });
                return;
            }

            res.json({
                message: 'A verification code has been sent to your email.',
                requiresTwoFactor: true,
                email: user.email,
            });
            return;
        }

        // Normal login
        await User.findByIdAndUpdate(user._id, { lastLoginAt: new Date() }, { runValidators: false });
        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET as string, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse({ ...user.toObject(), lastLoginAt: new Date() }), message: 'Login successful' });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ message: 'Server error during login' });
    }
};

// ── Verify 2FA code ───────────────────────────────────────────────────────────

export const verify2FA = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, code } = req.body as { email?: string; code?: string };
        if (!email || !code) { res.status(400).json({ message: 'Email and code are required' }); return; }

        const user = await User.findOne({ email: email.toLowerCase().trim() })
            .select('+twoFactorCode +twoFactorExpires');

        if (!user) { res.status(404).json({ message: 'Account not found' }); return; }

        if (!user.twoFactorCode || !user.twoFactorExpires) {
            res.status(400).json({ message: 'No 2FA code found. Please sign in again.' });
            return;
        }
        if (new Date() > user.twoFactorExpires) {
            res.status(400).json({ message: '2FA code expired. Please sign in again.' });
            return;
        }
        if (user.twoFactorCode !== code.trim()) {
            res.status(400).json({ message: 'Invalid 2FA code' });
            return;
        }

        await User.findByIdAndUpdate(user._id, {
            twoFactorCode: undefined,
            twoFactorExpires: undefined,
            lastLoginAt: new Date(),
        });

        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET as string, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse({ ...user.toObject(), lastLoginAt: new Date() }), message: 'Login successful' });
    } catch (err) {
        console.error('Verify 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Google Sign-In ────────────────────────────────────────────────────────────

export const googleAuth = async (req: Request, res: Response): Promise<void> => {
    try {
        const { idToken } = req.body as { idToken?: string };
        if (!idToken) { res.status(400).json({ message: 'Google ID token is required' }); return; }

        const googleRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
        const googleData = await googleRes.json() as any;

        if (googleData.error) {
            res.status(401).json({ message: 'Invalid Google token' });
            return;
        }

        if (process.env.GOOGLE_CLIENT_ID && googleData.aud !== process.env.GOOGLE_CLIENT_ID) {
            res.status(401).json({ message: 'Token not issued for this application' });
            return;
        }

        const { sub: googleId, email, name, picture: avatar } = googleData;
        if (!email || !googleId) {
            res.status(400).json({ message: 'Could not retrieve account info from Google' });
            return;
        }

        let user = await User.findOne({ $or: [{ googleId }, { email: email.toLowerCase() }] });

        if (!user) {
            user = new User({
                googleId,
                email: email.toLowerCase(),
                name: name || email.split('@')[0],
                avatar: avatar || undefined,
                isEmailVerified: true,
                twoFactorEnabled: false,
                isActive: true,
                lastLoginAt: new Date(),
                notificationSettings: {
                    email: true, push: true, inApp: true,
                    taskAssigned: true, taskCompleted: true,
                    teamInvitations: true, dailyReminder: false,
                },
            });
            await user.save();
        } else {
            const updates: any = { lastLoginAt: new Date() };
            if (!user.googleId) { updates.googleId = googleId; updates.isEmailVerified = true; }
            if (!user.avatar && avatar) updates.avatar = avatar;
            await User.findByIdAndUpdate(user._id, updates, { runValidators: false });
            user = await User.findById(user._id) as any;
        }

        const token = jwt.sign({ userId: user!._id }, process.env.JWT_SECRET as string, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse(user!.toObject()), message: 'Google sign-in successful' });
    } catch (err) {
        console.error('Google auth error:', err);
        res.status(500).json({ message: 'Server error during Google sign-in' });
    }
};