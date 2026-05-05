import cron from 'node-cron';
import { cleanupOldNotifications, sendDueDateReminders } from './notificationService.js';
import { runDailyCleanup } from './cleanupScheduler.js';

// scheduler service
export const startScheduler = () => {
    try {
        // Daily cleanup at 12:05 AM UTC (existing)
        cron.schedule('5 0 * * *', async () => {
            console.log('⏰ Running daily cleanup...');
            await runDailyCleanup();
        }, { timezone: "UTC" });

        // Clean up old notifications weekly (Sundays at 2 AM UTC)
        cron.schedule('0 2 * * 0', async () => {
            console.log('🧹 Running weekly notification cleanup...');
            await cleanupOldNotifications(30); // Keep notifications for 30 days
        }, { timezone: "UTC" });

        // Send due date reminders daily at 9 AM UTC
        cron.schedule('0 9 * * *', async () => {
            console.log('⏰ Sending due date reminders...');
            await sendDueDateReminders();
        }, { timezone: "UTC" });

        console.log('📅 Scheduler started with auto cleanup, notification and reminder services');
    } catch (error) {
        console.error('❌ Error starting scheduler:', error);
    }
};