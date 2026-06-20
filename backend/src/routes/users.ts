import { Router } from 'express';
import {
    getProfile,
    updateProfile,
    updateNotificationSettings,
    registerFcmToken,
    removeFcmToken,
    findByInviteId,
    searchUsers,
    changePassword,
    deleteAccount,
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
router.put('/change-password', changePassword);
router.delete('/account', deleteAccount);
router.post('/2fa/enable', enableTwoFactor);
router.post('/2fa/disable', disableTwoFactor);

export default router;