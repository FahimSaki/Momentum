"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const taskController_1 = require("../controllers/taskController");
const middle_auth_1 = require("../middleware/middle_auth");
const router = (0, express_1.Router)();
router.use(middle_auth_1.authenticateToken);
router.post('/', taskController_1.createTask);
router.get('/', taskController_1.getUserTasks);
router.get('/history', taskController_1.getTaskHistory);
router.get('/dashboard-stats', taskController_1.getDashboardStats);
router.get('/team/:teamId', taskController_1.getTeamTasks);
router.put('/:id', taskController_1.updateTask);
router.patch('/:id/complete', taskController_1.completeTask);
router.delete('/:id', taskController_1.deleteTask);
exports.default = router;
//# sourceMappingURL=tasks.js.map