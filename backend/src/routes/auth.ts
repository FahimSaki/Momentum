import { Router, Request, Response } from 'express';
import {
    login, register, verifyEmail, resendVerification,
    googleAuth, verify2FA,
} from '../controllers/authController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.post('/login', login);
router.post('/register', register);
router.post('/verify-email', verifyEmail);
router.post('/resend-verification', resendVerification);
router.post('/google', googleAuth);
router.post('/verify-2fa', verify2FA);

router.post('/logout', (_req: Request, res: Response) => {
    res.json({ message: 'Logged out successfully' });
});

router.get('/validate', authenticateToken, (req: Request, res: Response) => {
    res.json({
        valid: true,
        userId: (req as any).userId,
        user: {
            id: (req as any).user._id,
            name: (req as any).user.name,
            email: (req as any).user.email,
            isEmailVerified: (req as any).user.isEmailVerified,
            twoFactorEnabled: (req as any).user.twoFactorEnabled,
        },
    });
});

export default router;