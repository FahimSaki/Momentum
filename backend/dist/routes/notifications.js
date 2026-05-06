"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const notificationController_1 = require("../controllers/notificationController");
const middle_auth_1 = require("../middleware/middle_auth");
const router = (0, express_1.Router)();
router.use(middle_auth_1.authenticateToken);
router.get('/', notificationController_1.getNotifications);
router.get('/unread-count', notificationController_1.getUnreadCount);
router.patch('/:notificationId/read', notificationController_1.markAsRead);
router.patch('/mark-all-read', notificationController_1.markAllAsRead);
router.delete('/:notificationId', notificationController_1.deleteNotification);
exports.default = router;
//# sourceMappingURL=notifications.js.map