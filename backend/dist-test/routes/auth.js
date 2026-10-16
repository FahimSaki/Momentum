"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const authController_1 = require("../controllers/authController");
const authMiddleware_1 = require("../middleware/authMiddleware");
const router = (0, express_1.Router)();
router.post('/login', authController_1.login);
router.post('/register', authController_1.register);
router.post('/verify-email', authController_1.verifyEmail);
router.post('/resend-verification', authController_1.resendVerification);
router.post('/google', authController_1.googleAuth);
router.post('/verify-2fa', authController_1.verify2FA);
router.post('/forgot-password', authController_1.forgotPassword);
router.post('/reset-password', authController_1.resetPassword);
router.post('/logout', (_req, res) => {
    res.json({ message: 'Logged out successfully' });
});
router.get('/validate', authMiddleware_1.authenticateToken, (req, res) => {
    res.json({
        valid: true,
        userId: req.userId,
        user: {
            id: req.user._id,
            name: req.user.name,
            email: req.user.email,
            isEmailVerified: req.user.isEmailVerified,
            twoFactorEnabled: req.user.twoFactorEnabled,
        },
    });
});
exports.default = router;
