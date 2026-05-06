"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startScheduler = void 0;
const node_cron_1 = __importDefault(require("node-cron"));
const cleanupScheduler_1 = require("./cleanupScheduler");
const notificationService_1 = require("./notificationService");
const startScheduler = () => {
    try {
        // Daily cleanup at 12:05 AM UTC
        node_cron_1.default.schedule('5 0 * * *', async () => {
            console.log('⏰ Running daily cleanup...');
            try {
                await (0, cleanupScheduler_1.runDailyCleanup)();
            }
            catch (err) {
                console.error('❌ Daily cleanup error (non-fatal):', err);
            }
        }, { timezone: 'UTC' });
        // Clean old notifications weekly (Sundays at 2 AM UTC)
        node_cron_1.default.schedule('0 2 * * 0', async () => {
            console.log('🧹 Running weekly notification cleanup...');
            try {
                await (0, notificationService_1.cleanupOldNotifications)(30);
            }
            catch (err) {
                console.error('❌ Notification cleanup error (non-fatal):', err);
            }
        }, { timezone: 'UTC' });
        // Send due date reminders daily at 9 AM UTC
        node_cron_1.default.schedule('0 9 * * *', async () => {
            console.log('⏰ Sending due date reminders...');
            try {
                await (0, notificationService_1.sendDueDateReminders)();
            }
            catch (err) {
                console.error('❌ Due date reminder error (non-fatal):', err);
            }
        }, { timezone: 'UTC' });
        console.log('📅 Scheduler started (cleanup, notifications, reminders)');
    }
    catch (err) {
        console.error('❌ Error starting scheduler:', err);
    }
};
exports.startScheduler = startScheduler;
//# sourceMappingURL=schedulerService.js.map