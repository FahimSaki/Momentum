import express from 'express';
import {
    getUserProfile,
    searchUsers,
    getUserByInviteId,
    updatePrivacySettings
} from '../controllers/userController.js';

const router = express.Router();

// Get current user profile
router.get('/profile', getUserProfile);

// Search users for team invitations
router.get('/search', searchUsers);

// Get user by invite ID
router.get('/invite/:inviteId', getUserByInviteId);

// Update privacy settings
router.put('/privacy', updatePrivacySettings);

export default router;