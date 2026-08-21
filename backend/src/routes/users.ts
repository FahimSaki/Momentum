import { Router } from 'express';
import {
    getProfile,
    updateProfile,
    updateNotificationSettings,
    registerFcmToken,
    removeFcmToken,
    findByInviteId,
    searchUsers,
    requestPasswordChange,
    confirmPasswordChange,
    requestAccountDeletion,
    confirmAccountDeletion,
    enableTwoFactor,
    disableTwoFactor,
} from '../controllers/userController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.use(authenticateToken);

router.get('/profile', getProfile);
router.put('/profile', updateProfile);
router.put('/notification-settings', updateNotificationSettings);
router.post('/fcm-token', registerFcmToken);
router.delete('/fcm-token', removeFcmToken);
router.get('/invite/:inviteId', findByInviteId);
router.get('/search', searchUsers);
router.post('/request-password-change', requestPasswordChange);
router.post('/confirm-password-change', confirmPasswordChange);
router.post('/request-account-deletion', requestAccountDeletion);
router.post('/confirm-account-deletion', confirmAccountDeletion);
router.post('/2fa/enable', enableTwoFactor);
router.post('/2fa/disable', disableTwoFactor);

export default router;