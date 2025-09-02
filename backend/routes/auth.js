import express from 'express';
import { login, register } from '../controllers/authController.js';
const router = express.Router();

router.post('/login', login);
router.post('/register', register);

// ADD MISSING LOGOUT ROUTE
router.post('/logout', (req, res) => {
    // Since we're using stateless JWT, just return success
    // Client will handle token removal
    res.json({ message: 'Logged out successfully' });
});

// TODO: Add Google OAuth routes

export default router;