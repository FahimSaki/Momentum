import cron from 'node-cron';
import Task from '../models/Task.js';
import TaskHistory from '../models/TaskHistory.js';

// Helper function to save task to history before deletion
const saveTaskToHistory = async (task) => {
    if (task.completedDays?.length > 0) {
        try {
            // Check if this task's history already exists to avoid duplicates
            const existingHistory = await TaskHistory.findOne({
                userId: task.assignedTo,
                taskName: task.name
            });

            if (existingHistory) {
                // Merge completion days and remove duplicates
                const allDays = [...existingHistory.completedDays, ...task.completedDays];
                const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))].map(d => new Date(d));
                existingHistory.completedDays = uniqueDays;
                await existingHistory.save();
                console.log(`Updated existing history for "${task.name}" with ${task.completedDays.length} new completion days`);
            } else {
                // Create new history record
                await TaskHistory.create({
                    userId: task.assignedTo,
                    completedDays: task.completedDays,
                    taskName: task.name
                });
                console.log(`Saved task "${task.name}" to history with ${task.completedDays.length} completion days`);
            }
        } catch (error) {
            console.error(`Error saving task "${task.name}" to history:`, error);
            // Don't throw - continue with other tasks
        }
    }
};

// Function to archive completed tasks (step 1)
const archiveCompletedTasks = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const result = await Task.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        console.log(`✅ Archived ${result.modifiedCount} completed tasks that were completed before ${today.toDateString()}`);
        return result.modifiedCount;
    } catch (error) {
        console.error('❌ Error archiving completed tasks:', error);
        return 0; // Return 0 instead of throwing
    }
};

// Function to delete old archived tasks and preserve data (step 2)
const deleteOldArchivedTasks = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const tasksToDelete = await Task.find({
            isArchived: true,
            archivedAt: { $lt: today }
        });

        console.log(`Found ${tasksToDelete.length} archived tasks to delete (archived before ${today.toDateString()})`);

        let preservedCount = 0;
        for (const task of tasksToDelete) {
            try {
                await saveTaskToHistory(task);
                await task.deleteOne();
                preservedCount++;
            } catch (taskError) {
                console.error(`Error processing task "${task.name}":`, taskError);
                // Continue with next task instead of crashing
            }
        }

        console.log(`✅ Deleted ${preservedCount} tasks and preserved their history`);
        return preservedCount;
    } catch (error) {
        console.error('❌ Error deleting old archived tasks:', error);
        return 0; // Return 0 instead of throwing
    }
};

// Function to clean up old completion days from active tasks
const removeOldCompletionDays = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const tasks = await Task.find({});
        let cleanedCount = 0;

        for (const task of tasks) {
            try {
                // Save to history BEFORE removing completion days
                const oldCompletions = task.completedDays.filter(date => new Date(date) < today);

                if (oldCompletions.length > 0) {
                    const taskWithOldData = {
                        ...task.toObject(),
                        completedDays: oldCompletions
                    };

                    await saveTaskToHistory(taskWithOldData);
                }

                // Now remove old completions (keep only today's completions)
                const beforeLength = task.completedDays.length;
                task.completedDays = task.completedDays.filter(date => new Date(date) >= today);

                if (beforeLength !== task.completedDays.length) {
                    await task.save();
                    cleanedCount++;
                }
            } catch (taskError) {
                console.error(`Error cleaning task "${task.name}":`, taskError);
                // Continue with next task
            }
        }

        console.log(`✅ Cleaned old completion days from ${cleanedCount} tasks (removed completions before ${today.toDateString()})`);
        return cleanedCount;
    } catch (error) {
        console.error('❌ Error removing old completion days:', error);
        return 0;
    }
};

// Main cleanup function that runs daily - WRAPPED IN TRY-CATCH
const runDailyCleanup = async () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);

    console.log('🧹 Starting daily task cleanup...');
    console.log(`📅 Today: ${today.toDateString()}`);
    console.log(`📅 Yesterday: ${yesterday.toDateString()}`);

    try {
        // Step 1: Archive tasks completed before today
        console.log('📦 Step 1: Archiving tasks completed before today...');
        const archivedCount = await archiveCompletedTasks();

        // Step 2: Delete tasks archived before today and preserve their data
        console.log('🗑️ Step 2: Deleting tasks archived before today...');
        const deletedCount = await deleteOldArchivedTasks();

        // Step 3: Clean old completion days from active tasks
        console.log('🧽 Step 3: Cleaning old completion days from active tasks...');
        const cleanedCount = await removeOldCompletionDays();

        const result = {
            archivedTasks: archivedCount,
            deletedAndPreservedTasks: deletedCount,
            cleanedTasks: cleanedCount,
            processedDate: today.toDateString(),
            timestamp: now.toISOString()
        };

        console.log('✅ Daily cleanup completed:', result);

        // 🔧 IMPORTANT: Force garbage collection to prevent memory issues
        if (global.gc) {
            global.gc();
            console.log('🗑️ Garbage collection triggered');
        }

        return result;

    } catch (error) {
        console.error('❌ Daily cleanup failed:', error);
        // 🔧 CRITICAL: Don't re-throw the error - just log it
        // Re-throwing could crash the server
        return {
            error: error.message,
            timestamp: now.toISOString(),
            status: 'failed'
        };
    }
};

// Schedule cleanup to run every day at 12:05 AM UTC
const startCleanupScheduler = () => {
    try {
        // Run at 12:05 AM UTC every day
        cron.schedule('5 0 * * *', async () => {
            const now = new Date();
            console.log(`⏰ Scheduled cleanup triggered at: ${now.toISOString()}`);

            try {
                await runDailyCleanup();
                console.log('✅ Scheduled cleanup completed successfully');
            } catch (error) {
                console.error('❌ Scheduled cleanup error (non-fatal):', error);
                // Don't crash the server
            }
        }, {
            scheduled: true,
            timezone: "UTC"
        });

        console.log('📅 Cleanup scheduler started - will run daily at 12:05 AM UTC');
        console.log('🔄 Cleanup logic: Tasks completed on calendar day X will be deleted at 12:05 AM on day X+2');
    } catch (error) {
        console.error('❌ Error starting cleanup scheduler:', error);
        // Don't crash the server if scheduler fails to start
    }
};

// Manual cleanup function for testing/debugging - WRAPPED IN TRY-CATCH
const runManualCleanup = async () => {
    try {
        console.log('🔧 Running manual cleanup...');
        const result = await runDailyCleanup();
        console.log('✅ Manual cleanup finished:', result);
        return result;
    } catch (error) {
        console.error('❌ Manual cleanup error:', error);
        // Return error info instead of throwing
        return {
            error: error.message,
            timestamp: new Date().toISOString(),
            status: 'failed'
        };
    }
};

export {
    startCleanupScheduler,
    runManualCleanup,
    runDailyCleanup
};