import cron from 'node-cron';
import { runDailyCleanup } from './cleanupScheduler';
import { sendDueDateReminders, cleanupOldNotifications } from './notificationService';

export const startScheduler = (): void => {
    try {
        // Daily cleanup at 12:05 AM UTC
        cron.schedule('5 0 * * *', async () => {
            console.log('⏰ Running daily cleanup...');
            try { await runDailyCleanup(); }
            catch (err) { console.error('❌ Daily cleanup error (non-fatal):', err); }
        }, { timezone: 'UTC' });

        // Clean old notifications weekly (Sundays at 2 AM UTC)
        cron.schedule('0 2 * * 0', async () => {
            console.log('🧹 Running weekly notification cleanup...');
            try { await cleanupOldNotifications(30); }
            catch (err) { console.error('❌ Notification cleanup error (non-fatal):', err); }
        }, { timezone: 'UTC' });

        // Send due date reminders daily at 9 AM UTC
        cron.schedule('0 9 * * *', async () => {
            console.log('⏰ Sending due date reminders...');
            try { await sendDueDateReminders(); }
            catch (err) { console.error('❌ Due date reminder error (non-fatal):', err); }
        }, { timezone: 'UTC' });

        console.log('📅 Scheduler started (cleanup, notifications, reminders)');
    } catch (err) {
        console.error('❌ Error starting scheduler:', err);
    }
};