"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetPassword = exports.forgotPassword = exports.googleAuth = exports.verify2FA = exports.login = exports.resendVerification = exports.verifyEmail = exports.register = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const User_1 = __importDefault(require("../models/User"));
const emailService_1 = require("../services/emailService");
const otpService_1 = require("../services/otpService");
// Email verification codes are valid for this long. resendVerification's
// 60-second cooldown derives "time since last send" from this value — keep
// them in sync.
const EMAIL_VERIFICATION_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes
const PASSWORD_RESET_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
const TWO_FACTOR_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
function buildUserResponse(user) {
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
        hasPassword: !!user.password,
    };
}
// Register
const register = async (req, res) => {
    try {
        const { email, password, name } = req.body;
        if (!email?.trim()) {
            res.status(400).json({ message: 'Email is required' });
            return;
        }
        if (!password || password.length < 6) {
            res.status(400).json({ message: 'Password must be at least 6 characters' });
            return;
        }
        if (!name?.trim()) {
            res.status(400).json({ message: 'Name is required' });
            return;
        }
        const trimmedEmail = email.toLowerCase().trim();
        const existing = await User_1.default.findOne({ email: trimmedEmail });
        if (existing) {
            // If the account exists but was never verified, allow re-registration.
            // was working — they have a DB record but never received the OTP.
            if (!existing.isEmailVerified) {
                const hashedPassword = await bcryptjs_1.default.hash(password, 12);
                await (0, otpService_1.generateAndSendOtp)({
                    persist: async (code, expiresAt) => {
                        await User_1.default.findByIdAndUpdate(existing._id, {
                            password: hashedPassword,
                            name: name.trim(),
                            emailVerificationCode: code,
                            emailVerificationExpires: expiresAt,
                        });
                    },
                    send: (code) => (0, emailService_1.sendVerificationEmail)(trimmedEmail, name.trim(), code),
                    expiryMs: EMAIL_VERIFICATION_EXPIRY_MS,
                    logContext: `${trimmedEmail} (re-registration verification)`,
                });
                res.status(201).json({
                    message: 'Account created. Check your email for a 6-digit verification code.',
                    requiresVerification: true,
                    email: trimmedEmail,
                });
                return;
            }
            res.status(400).json({ message: 'An account with this email already exists. Please login instead.' });
            return;
        }
        const hashedPassword = await bcryptjs_1.default.hash(password, 12);
        const user = new User_1.default({
            email: trimmedEmail,
            password: hashedPassword,
            name: name.trim(),
            isEmailVerified: false,
            twoFactorEnabled: false,
            isActive: true,
            lastLoginAt: new Date(),
            notificationSettings: {
                email: true, push: true, inApp: true,
                taskAssigned: true, taskCompleted: true,
                teamInvitations: true, dailyReminder: false,
            },
        });
        // register() never fails the request over an email hiccup — the
        // account is already usable and the user can request a new code —
        // so the `sent` flag from generateAndSendOtp isn't checked here.
        await (0, otpService_1.generateAndSendOtp)({
            persist: async (code, expiresAt) => {
                user.emailVerificationCode = code;
                user.emailVerificationExpires = expiresAt;
                await user.save();
            },
            send: (code) => (0, emailService_1.sendVerificationEmail)(trimmedEmail, name.trim(), code),
            expiryMs: EMAIL_VERIFICATION_EXPIRY_MS,
            logContext: `${trimmedEmail} (verification)`,
        });
        res.status(201).json({
            message: 'Account created. Check your email for a 6-digit verification code.',
            requiresVerification: true,
            email: trimmedEmail,
        });
    }
    catch (err) {
        console.error('Register error:', err);
        if (err.code === 11000) {
            // Identify which field caused the duplicate so we give an accurate message.
            // inviteId also has a unique index and can trigger 11000.
            const field = Object.keys(err.keyValue || {})[0];
            if (field === 'email') {
                res.status(400).json({ message: 'An account with this email already exists. Please login instead.' });
            }
            else {
                // Transient inviteId collision — extremely rare, safe to retry.
                res.status(500).json({ message: 'Registration failed due to a server conflict. Please try again.' });
            }
            return;
        }
        res.status(500).json({ message: 'Server error during registration' });
    }
};
exports.register = register;
// Verify email OTP 
const verifyEmail = async (req, res) => {
    try {
        const { email, code } = req.body;
        if (!email || !code) {
            res.status(400).json({ message: 'Email and code are required' });
            return;
        }
        const user = await User_1.default.findOne({ email: email.toLowerCase().trim() })
            .select('+emailVerificationCode +emailVerificationExpires');
        if (!user) {
            res.status(404).json({ message: 'Account not found' });
            return;
        }
        if (user.isEmailVerified) {
            res.json({ message: 'Email already verified' });
            return;
        }
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
    }
    catch (err) {
        console.error('Verify email error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.verifyEmail = verifyEmail;
// Resend verification code 
const resendVerification = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            res.status(400).json({ message: 'Email is required' });
            return;
        }
        const user = await User_1.default.findOne({ email: email.toLowerCase().trim() })
            .select('+emailVerificationExpires');
        if (!user) {
            res.status(404).json({ message: 'Account not found' });
            return;
        }
        if (user.isEmailVerified) {
            res.json({ message: 'Email is already verified' });
            return;
        }
        // Simple rate limit: block if a code was sent in the last 60 seconds
        if (user.emailVerificationExpires) {
            const elapsed = EMAIL_VERIFICATION_EXPIRY_MS - (user.emailVerificationExpires.getTime() - Date.now());
            if (elapsed < 60000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }
        const { sent } = await (0, otpService_1.generateAndSendOtp)({
            persist: async (code, expiresAt) => {
                await User_1.default.findByIdAndUpdate(user._id, {
                    emailVerificationCode: code,
                    emailVerificationExpires: expiresAt,
                });
            },
            send: (code) => (0, emailService_1.sendVerificationEmail)(user.email, user.name, code),
            expiryMs: EMAIL_VERIFICATION_EXPIRY_MS,
            logContext: `${user.email} (resend verification)`,
        });
        if (!sent) {
            res.status(500).json({ message: 'Failed to send verification code. Check server logs for details.' });
            return;
        }
        res.json({ message: 'Verification code sent to your email.' });
    }
    catch (err) {
        console.error('Resend verification error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.resendVerification = resendVerification;
// Login 
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            res.status(400).json({ message: 'Email and password are required' });
            return;
        }
        const trimmedEmail = email.toLowerCase().trim();
        const user = await User_1.default.findOne({ email: trimmedEmail })
            .select('+emailVerificationCode +emailVerificationExpires +twoFactorCode +twoFactorExpires');
        if (!user) {
            res.status(401).json({ message: 'Invalid email or password' });
            return;
        }
        if (!user.password) {
            res.status(401).json({ message: 'This account uses Google Sign-In. Please use the Google button.' });
            return;
        }
        const isMatch = await bcryptjs_1.default.compare(password, user.password);
        if (!isMatch) {
            res.status(401).json({ message: 'Invalid email or password' });
            return;
        }
        if (!user.isEmailVerified) {
            // Legacy accounts created before email verification was required have no
            // stored OTP code. They proved ownership via password so auto-verify them
            // and fall through to normal login rather than blocking them forever.
            if (!user.emailVerificationCode) {
                await User_1.default.findByIdAndUpdate(user._id, { isEmailVerified: true }, { runValidators: false });
                // Fall through to the login logic below
            }
            else {
                // Newly registered but unverified — resend OTP and block
                await (0, otpService_1.generateAndSendOtp)({
                    persist: async (code, expiresAt) => {
                        await User_1.default.findByIdAndUpdate(user._id, {
                            emailVerificationCode: code,
                            emailVerificationExpires: expiresAt,
                        });
                    },
                    send: (code) => (0, emailService_1.sendVerificationEmail)(user.email, user.name, code),
                    expiryMs: EMAIL_VERIFICATION_EXPIRY_MS,
                    logContext: `${user.email} (login re-send verification)`,
                });
                res.status(403).json({
                    message: 'Please verify your email first. A new code has been sent.',
                    requiresVerification: true,
                    email: user.email,
                });
                return;
            }
        }
        // 2FA challenge
        if (user.twoFactorEnabled) {
            const { sent } = await (0, otpService_1.generateAndSendOtp)({
                persist: async (code, expiresAt) => {
                    await User_1.default.findByIdAndUpdate(user._id, {
                        twoFactorCode: code,
                        twoFactorExpires: expiresAt,
                    });
                },
                send: (code) => (0, emailService_1.send2FACode)(user.email, user.name, code),
                expiryMs: TWO_FACTOR_EXPIRY_MS,
                logContext: `${user.email} (2FA login)`,
            });
            if (!sent) {
                await User_1.default.findByIdAndUpdate(user._id, {
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
        await User_1.default.findByIdAndUpdate(user._id, { lastLoginAt: new Date() }, { runValidators: false });
        const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse({ ...user.toObject(), lastLoginAt: new Date() }), message: 'Login successful' });
    }
    catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ message: 'Server error during login' });
    }
};
exports.login = login;
// Verify 2FA code 
const verify2FA = async (req, res) => {
    try {
        const { email, code } = req.body;
        if (!email || !code) {
            res.status(400).json({ message: 'Email and code are required' });
            return;
        }
        const user = await User_1.default.findOne({ email: email.toLowerCase().trim() })
            .select('+twoFactorCode +twoFactorExpires');
        if (!user) {
            res.status(404).json({ message: 'Account not found' });
            return;
        }
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
        await User_1.default.findByIdAndUpdate(user._id, {
            twoFactorCode: undefined,
            twoFactorExpires: undefined,
            lastLoginAt: new Date(),
        });
        const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse({ ...user.toObject(), lastLoginAt: new Date() }), message: 'Login successful' });
    }
    catch (err) {
        console.error('Verify 2FA error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.verify2FA = verify2FA;
// Google Sign-In 
const googleAuth = async (req, res) => {
    try {
        const { idToken } = req.body;
        if (!idToken) {
            res.status(400).json({ message: 'Google ID token is required' });
            return;
        }
        const googleRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
        const googleData = await googleRes.json();
        if (googleData.error) {
            res.status(401).json({ message: 'Invalid Google token' });
            return;
        }
        // GOOGLE_CLIENT_ID may hold a single client ID or a comma-separated
        // allowlist (mobile serverClientId + web clientId from two GCP
        // projects). Split on commas and check membership — a strict
        // equality check here would reject every token whenever the env var
        // holds more than one ID.
        if (process.env.GOOGLE_CLIENT_ID) {
            const allowedClientIds = process.env.GOOGLE_CLIENT_ID
                .split(',')
                .map((id) => id.trim())
                .filter(Boolean);
            if (allowedClientIds.length > 0 && !allowedClientIds.includes(googleData.aud)) {
                console.warn(`Google auth aud mismatch: received "${googleData.aud}", allowed: [${allowedClientIds.join(', ')}]`);
                res.status(401).json({ message: 'Token not issued for this application' });
                return;
            }
        }
        const { sub: googleId, email, name, picture: avatar } = googleData;
        if (!email || !googleId) {
            res.status(400).json({ message: 'Could not retrieve account info from Google' });
            return;
        }
        let user = await User_1.default.findOne({ $or: [{ googleId }, { email: email.toLowerCase() }] });
        if (!user) {
            // Brand-new account — always created with twoFactorEnabled: false,
            // so a first-ever Google sign-in can never hit the 2FA gate below.
            // isEmailVerified stays true directly here, same as always — no
            // OTP step for Google sign-ups.
            user = new User_1.default({
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
            const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
            res.json({ token, user: buildUserResponse(user.toObject()), message: 'Google sign-in successful' });
            return;
        }
        // Existing account — link identity fields only. lastLoginAt is
        // intentionally NOT set here; it's set further down, after the 2FA
        // gate, so a 2FA-enabled account's login timestamp only advances
        // once the emailed code is actually verified — same ordering
        // login() already uses for password sign-in.
        const updates = {};
        if (!user.googleId) {
            updates.googleId = googleId;
            updates.isEmailVerified = true;
        }
        if (!user.avatar && avatar)
            updates.avatar = avatar;
        if (Object.keys(updates).length > 0) {
            await User_1.default.findByIdAndUpdate(user._id, updates, { runValidators: false });
            user = await User_1.default.findById(user._id);
        }
        // 2FA challenge — same gate login() uses. An account that has
        // turned on 2FA in Settings now requires the emailed code on
        // Google sign-in too, not just password sign-in — regardless of
        // which method was used when the toggle was originally flipped.
        if (user.twoFactorEnabled) {
            const { sent } = await (0, otpService_1.generateAndSendOtp)({
                persist: async (code, expiresAt) => {
                    await User_1.default.findByIdAndUpdate(user._id, {
                        twoFactorCode: code,
                        twoFactorExpires: expiresAt,
                    });
                },
                send: (code) => (0, emailService_1.send2FACode)(user.email, user.name, code),
                expiryMs: TWO_FACTOR_EXPIRY_MS,
                logContext: `${user.email} (2FA Google sign-in)`,
            });
            if (!sent) {
                await User_1.default.findByIdAndUpdate(user._id, {
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
        await User_1.default.findByIdAndUpdate(user._id, { lastLoginAt: new Date() }, { runValidators: false });
        const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse({ ...user.toObject(), lastLoginAt: new Date() }), message: 'Google sign-in successful' });
    }
    catch (err) {
        console.error('Google auth error:', err);
        res.status(500).json({ message: 'Server error during Google sign-in' });
    }
};
exports.googleAuth = googleAuth;
// Forgot password 
const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email?.trim()) {
            res.status(400).json({ message: 'Email is required' });
            return;
        }
        const trimmedEmail = email.toLowerCase().trim();
        const user = await User_1.default.findOne({ email: trimmedEmail })
            .select('+passwordResetExpires');
        if (!user) {
            res.status(404).json({ message: 'No account found with that email' });
            return;
        }
        if (!user.password) {
            res.status(400).json({ message: 'This account uses Google Sign-In. Please use the Google button to sign in.' });
            return;
        }
        // Simple rate limit: block if a code was sent recently and hasn't expired
        if (user.passwordResetExpires) {
            const elapsed = PASSWORD_RESET_EXPIRY_MS - (user.passwordResetExpires.getTime() - Date.now());
            if (elapsed < 60000) {
                res.status(429).json({ message: 'Please wait before requesting another code.' });
                return;
            }
        }
        const { sent } = await (0, otpService_1.generateAndSendOtp)({
            persist: async (code, expiresAt) => {
                await User_1.default.findByIdAndUpdate(user._id, {
                    passwordResetCode: code,
                    passwordResetExpires: expiresAt,
                });
            },
            send: (code) => (0, emailService_1.sendPasswordResetCode)(user.email, user.name, code),
            expiryMs: PASSWORD_RESET_EXPIRY_MS,
            logContext: `${user.email} (password reset)`,
        });
        if (!sent) {
            res.status(500).json({ message: 'Failed to send reset code. Please try again.' });
            return;
        }
        res.json({ message: 'A password reset code has been sent to your email.' });
    }
    catch (err) {
        console.error('Forgot password error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.forgotPassword = forgotPassword;
// Reset password 
const resetPassword = async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;
        if (!email || !code || !newPassword) {
            res.status(400).json({ message: 'Email, code, and new password are required' });
            return;
        }
        if (newPassword.length < 6) {
            res.status(400).json({ message: 'New password must be at least 6 characters' });
            return;
        }
        const user = await User_1.default.findOne({ email: email.toLowerCase().trim() })
            .select('+passwordResetCode +passwordResetExpires');
        if (!user) {
            res.status(404).json({ message: 'No account found with that email' });
            return;
        }
        if (!user.passwordResetCode || !user.passwordResetExpires) {
            res.status(400).json({ message: 'No reset code found. Please request a new one.' });
            return;
        }
        if (new Date() > user.passwordResetExpires) {
            res.status(400).json({ message: 'Reset code expired. Please request a new one.' });
            return;
        }
        if (user.passwordResetCode !== code.trim()) {
            res.status(400).json({ message: 'Invalid reset code' });
            return;
        }
        user.password = await bcryptjs_1.default.hash(newPassword, 12);
        user.passwordResetCode = undefined;
        user.passwordResetExpires = undefined;
        user.lastLoginAt = new Date();
        await user.save();
        const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: buildUserResponse(user.toObject()), message: 'Password reset successful' });
    }
    catch (err) {
        console.error('Reset password error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};
exports.resetPassword = resetPassword;
