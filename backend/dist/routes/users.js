"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const userController_1 = require("../controllers/userController");
const middle_auth_1 = require("../middleware/middle_auth");
const router = (0, express_1.Router)();
router.use(middle_auth_1.authenticateToken);
router.get('/profile', userController_1.getProfile);
router.put('/profile', userController_1.updateProfile);
router.put('/notification-settings', userController_1.updateNotificationSettings);
router.post('/fcm-token', userController_1.registerFcmToken);
router.delete('/fcm-token', userController_1.removeFcmToken);
router.get('/invite/:inviteId', userController_1.findByInviteId);
router.get('/search', userController_1.searchUsers);
router.put('/change-password', userController_1.changePassword);
router.delete('/account', userController_1.deleteAccount);
exports.default = router;
//# sourceMappingURL=users.js.map