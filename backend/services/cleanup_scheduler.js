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
        }
    }
};

// Function to archive completed habits (step 1)
const archiveCompletedHabits = async () => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Archive habits that were completed before today (yesterday or earlier)
        const result = await Habit.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        console.log(`✅ Archived ${result.modifiedCount} completed habits that were completed before ${today.toDateString()}`);
        return result.modifiedCount;
    } catch (error) {
        console.error('❌ Error archiving completed habits:', error);
        throw error;
    }
};

// Function to delete old archived habits and preserve data (step 2)
const deleteOldArchivedHabits = async () => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Delete habits that were archived before today (yesterday or earlier)
        const habitsToDelete = await Habit.find({
            isArchived: true,
            archivedAt: { $lt: today }
        });

        console.log(`Found ${habitsToDelete.length} archived habits to delete (archived before ${today.toDateString()})`);

        let preservedCount = 0;
        for (const habit of habitsToDelete) {
            await saveHabitToHistory(habit);
            await habit.deleteOne();
            preservedCount++;
        }

        console.log(`✅ Deleted ${preservedCount} habits and preserved their history`);
        return preservedCount;
    } catch (error) {
        console.error('❌ Error deleting old archived habits:', error);
        throw error;
    }
};

// Function to clean up old completion days from active habits
const removeOldCompletionDays = async () => {
    try {
        // Get today's date at 00:00:00 UTC (start of today)
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const habits = await Habit.find({});
        let cleanedCount = 0;

        for (const habit of habits) {
            // Save to history BEFORE removing completion days
            // Get completions from before today (yesterday and earlier)
            const oldCompletions = habit.completedDays.filter(date => new Date(date) < today);

            if (oldCompletions.length > 0) {
                // Create a temporary habit object with only old completions
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
        }

        console.log(`✅ Cleaned old completion days from ${cleanedCount} habits (removed completions before ${today.toDateString()})`);
        return cleanedCount;
    } catch (error) {
        console.error('❌ Error removing old completion days:', error);
        throw error;
    }
};

// Main cleanup function that runs daily
const runDailyCleanup = async () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);

    console.log('🧹 Starting daily habit cleanup...');
    console.log(`📅 Today: ${today.toDateString()}`);
    console.log(`📅 Yesterday: ${yesterday.toDateString()}`);

    try {
        // Step 1: Archive habits completed before today (yesterday and earlier)
        console.log('📦 Step 1: Archiving habits completed before today...');
        const archivedCount = await archiveCompletedHabits();

        // Step 2: Delete habits archived before today (yesterday and earlier) and preserve their data
        console.log('🗑️ Step 2: Deleting habits archived before today...');
        const deletedCount = await deleteOldArchivedHabits();

        // Step 3: Clean old completion days from active habits
        console.log('🧽 Step 3: Cleaning old completion days from active habits...');
        const cleanedCount = await removeOldCompletionDays();

        console.log(`✅ Daily cleanup completed:`, {
            archivedHabits: archivedCount,
            deletedAndPreservedHabits: deletedCount,
            cleanedHabits: cleanedCount,
            processedDate: today.toDateString(),
            timestamp: now.toISOString()
        });

    } catch (error) {
        console.error('❌ Daily cleanup failed:', error);
    }
};

// Schedule cleanup to run every day at 12:05 AM UTC
const startCleanupScheduler = () => {
    // Run at 12:05 AM UTC every day
    cron.schedule('5 0 * * *', async () => {
        const now = new Date();
        console.log(`⏰ Scheduled cleanup triggered at: ${now.toISOString()}`);
        console.log(`📅 This cleanup will process habits from: ${new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1).toDateString()}`);
        await runDailyCleanup();
    }, {
        scheduled: true,
        timezone: "UTC"
    });

    console.log('📅 Cleanup scheduler started - will run daily at 12:05 AM UTC');
    console.log('🔄 Cleanup logic: Habits completed on calendar day X will be deleted at 12:05 AM on day X+2');
    console.log('   Example: Habit completed Aug 8 at 2 PM → Archived Aug 9 at 12:05 AM → Deleted Aug 10 at 12:05 AM');
};

// Manual cleanup function for testing/debugging
const runManualCleanup = async () => {
    console.log('🔧 Running manual cleanup...');
    await runDailyCleanup();
};

export {
    startCleanupScheduler,
    runManualCleanup,
    runDailyCleanup
};