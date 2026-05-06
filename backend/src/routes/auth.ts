import { Router, Request, Response } from 'express';
import { login, register } from '../controllers/authController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.post('/login', login);
router.post('/register', register);

// ── LOGOUT (stateless JWT) ────────────────────────────────────────────────
router.post('/logout', (req: Request, res: Response) => {
    // JWT is stateless → just client-side token removal
    res.json({ message: 'Logged out successfully' });
});

// ── VALIDATE TOKEN ────────────────────────────────────────────────────────
router.get('/validate', authenticateToken, (req: Request, res: Response) => {
    // req.userId and req.user come from middleware
    res.json({
        valid: true,
        userId: (req as any).userId,
        user: {
            id: (req as any).user._id,
            name: (req as any).user.name,
            email: (req as any).user.email
        }
    });
});

export default router;