import express from 'express';
import { login, register } from '../controllers/authController.js';
import { authenticateToken } from '../middleware/middle_auth.js';
const router = express.Router();


router.post('/login', login);
router.post('/register', register);

// ADD MISSING LOGOUT ROUTE
router.post('/logout', (req, res) => {
    // Since we're using stateless JWT, just return success
    // Client will handle token removal
    res.json({ message: 'Logged out successfully' });
});

router.get('/validate', authenticateToken, (req, res) => {
    // If middleware passes, token is valid
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

// TODO: Add Google OAuth routes

export default router;