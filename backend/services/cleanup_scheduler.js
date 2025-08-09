import cron from 'node-cron';
import Habit from '../models/Habit.js';
import HabitHistory from '../models/HabitHistory.js';

// Helper function to save habit to history before deletion
const saveHabitToHistory = async (habit) => {
    if (habit.completedDays?.length > 0) {
        try {
            // Check if this habit's history already exists to avoid duplicates
            const existingHistory = await HabitHistory.findOne({
                userId: habit.assignedTo,
                habitName: habit.name
            });

            if (existingHistory) {
                // Merge completion days and remove duplicates
                const allDays = [...existingHistory.completedDays, ...habit.completedDays];
                const uniqueDays = [...new Set(allDays.map(d => d.toISOString()))].map(d => new Date(d));
                existingHistory.completedDays = uniqueDays;
                await existingHistory.save();
                console.log(`Updated existing history for "${habit.name}" with ${habit.completedDays.length} new completion days`);
            } else {
                // Create new history record
                await HabitHistory.create({
                    userId: habit.assignedTo,
                    completedDays: habit.completedDays,
                    habitName: habit.name
                });
                console.log(`Saved habit "${habit.name}" to history with ${habit.completedDays.length} completion days`);
            }
        } catch (error) {
            console.error(`Error saving habit "${habit.name}" to history:`, error);
            // Don't throw - continue with other habits
        }
    }
};

// Function to archive completed habits (step 1)
const archiveCompletedHabits = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const result = await Habit.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        console.log(`✅ Archived ${result.modifiedCount} completed habits that were completed before ${today.toDateString()}`);
        return result.modifiedCount;
    } catch (error) {
        console.error('❌ Error archiving completed habits:', error);
        return 0; // Return 0 instead of throwing
    }
};

// Function to delete old archived habits and preserve data (step 2)
const deleteOldArchivedHabits = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const habitsToDelete = await Habit.find({
            isArchived: true,
            archivedAt: { $lt: today }
        });

        console.log(`Found ${habitsToDelete.length} archived habits to delete (archived before ${today.toDateString()})`);

        let preservedCount = 0;
        for (const habit of habitsToDelete) {
            try {
                await saveHabitToHistory(habit);
                await habit.deleteOne();
                preservedCount++;
            } catch (habitError) {
                console.error(`Error processing habit "${habit.name}":`, habitError);
                // Continue with next habit instead of crashing
            }
        }

        console.log(`✅ Deleted ${preservedCount} habits and preserved their history`);
        return preservedCount;
    } catch (error) {
        console.error('❌ Error deleting old archived habits:', error);
        return 0; // Return 0 instead of throwing
    }
};

// Function to clean up old completion days from active habits
const removeOldCompletionDays = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const habits = await Habit.find({});
        let cleanedCount = 0;

        for (const habit of habits) {
            try {
                // Save to history BEFORE removing completion days
                const oldCompletions = habit.completedDays.filter(date => new Date(date) < today);

                if (oldCompletions.length > 0) {
                    const habitWithOldData = {
                        ...habit.toObject(),
                        completedDays: oldCompletions
                    };

                    await saveHabitToHistory(habitWithOldData);
                }

                // Now remove old completions (keep only today's completions)
                const beforeLength = habit.completedDays.length;
                habit.completedDays = habit.completedDays.filter(date => new Date(date) >= today);

                if (beforeLength !== habit.completedDays.length) {
                    await habit.save();
                    cleanedCount++;
                }
            } catch (habitError) {
                console.error(`Error cleaning habit "${habit.name}":`, habitError);
                // Continue with next habit
            }
        }

        console.log(`✅ Cleaned old completion days from ${cleanedCount} habits (removed completions before ${today.toDateString()})`);
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

    console.log('🧹 Starting daily habit cleanup...');
    console.log(`📅 Today: ${today.toDateString()}`);
    console.log(`📅 Yesterday: ${yesterday.toDateString()}`);

    try {
        // Step 1: Archive habits completed before today
        console.log('📦 Step 1: Archiving habits completed before today...');
        const archivedCount = await archiveCompletedHabits();

        // Step 2: Delete habits archived before today and preserve their data
        console.log('🗑️ Step 2: Deleting habits archived before today...');
        const deletedCount = await deleteOldArchivedHabits();

        // Step 3: Clean old completion days from active habits
        console.log('🧽 Step 3: Cleaning old completion days from active habits...');
        const cleanedCount = await removeOldCompletionDays();

        const result = {
            archivedHabits: archivedCount,
            deletedAndPreservedHabits: deletedCount,
            cleanedHabits: cleanedCount,
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
        console.log('🔄 Cleanup logic: Habits completed on calendar day X will be deleted at 12:05 AM on day X+2');
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