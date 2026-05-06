"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const authController_1 = require("../controllers/authController");
const middle_auth_1 = require("../middleware/middle_auth");
const router = (0, express_1.Router)();
router.post('/login', authController_1.login);
router.post('/register', authController_1.register);
// ── LOGOUT (stateless JWT) ────────────────────────────────────────────────
router.post('/logout', (req, res) => {
    // JWT is stateless → just client-side token removal
    res.json({ message: 'Logged out successfully' });
});
// ── VALIDATE TOKEN ────────────────────────────────────────────────────────
router.get('/validate', middle_auth_1.authenticateToken, (req, res) => {
    // req.userId and req.user come from middleware
    res.json({
        valid: true,
        userId: req.userId,
        user: {
            id: req.user._id,
            name: req.user.name,
            email: req.user.email
        }
    });
});
exports.default = router;
//# sourceMappingURL=auth.js.map