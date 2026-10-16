"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.runManualCleanup = exports.runDailyCleanup = exports.expireArchivedTasks = void 0;
const Task_1 = __importDefault(require("../models/Task"));
const taskHelpers_1 = require("../helpers/taskHelpers");
const archiveCompletedTasks = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const result = await Task_1.default.updateMany({ isArchived: false, lastCompletedDate: { $lt: today } }, { $set: { isArchived: true, archivedAt: new Date() } });
        console.log(`✅ Archived ${result.modifiedCount} tasks`);
        return result.modifiedCount;
    }
    catch (err) {
        console.error('❌ Error archiving tasks:', err);
        return 0;
    }
};
// Legacy rule, only for tasks archived before archiveExpiresAt existed.
const deleteOldArchivedTasks = async () => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const tasksToDelete = await Task_1.default.find({ isArchived: true, archivedAt: { $lt: today }, archiveExpiresAt: { $exists: false } });
        let count = 0;
        for (const task of tasksToDelete) {
            try {
                await (0, taskHelpers_1.saveTaskToHistory)(task);
                await task.deleteOne();
                count++;
            }
            catch (err) {
                console.error(`Error processing task "${task.name}":`, err);
            }
        }
        console.log(`✅ Deleted ${count} tasks, history preserved`);
        return count;
    }
    catch (err) {
        console.error('❌ Error deleting archived tasks:', err);
        return 0;
    }
};
/** Removes completed tasks whose completer's local day has ended, saving their
 *  completion days to history first. Runs hourly. */
const expireArchivedTasks = async () => {
    try {
        const expired = await Task_1.default.find({ isArchived: true, archiveExpiresAt: { $lte: new Date() } });
        let count = 0;
        for (const task of expired) {
            try {
                await (0, taskHelpers_1.saveTaskToHistory)(task);
                await task.deleteOne();
                count++;
            }
            catch (err) {
                console.error(`Error expiring task "${task.name}":`, err);
            }
        }
        if (count > 0)
            console.log(`✅ Expired ${count} completed tasks, history preserved`);
        return count;
    }
    catch (err) {
        console.error('❌ Error expiring archived tasks:', err);
        return 0;
    }
};
exports.expireArchivedTasks = expireArchivedTasks;
const removeOldCompletionDays = async () => {
    try {
        // Completion days are day stamps naming the completing user's own
        // calendar date, which can be a day behind UTC for users west of it.
        // Only stamps older than yesterday are safe to treat as old, otherwise
        // a completion made just after UTC midnight would lose its day here.
        const cutoff = new Date();
        cutoff.setUTCHours(0, 0, 0, 0);
        cutoff.setTime(cutoff.getTime() - 24 * 60 * 60 * 1000);
        const tasks = await Task_1.default.find({});
        let cleaned = 0;
        for (const task of tasks) {
            try {
                const oldCompletions = task.completedDays.filter((d) => new Date(d) < cutoff);
                if (oldCompletions.length > 0) {
                    await (0, taskHelpers_1.saveTaskToHistory)({ ...task.toObject(), completedDays: oldCompletions });
                }
                const before = task.completedDays.length;
                task.completedDays = task.completedDays.filter((d) => new Date(d) >= cutoff);
                if (before !== task.completedDays.length) {
                    await task.save();
                    cleaned++;
                }
            }
            catch (err) {
                console.error(`Error cleaning task "${task.name}":`, err);
            }
        }
        console.log(`✅ Cleaned old completion days from ${cleaned} tasks`);
        return cleaned;
    }
    catch (err) {
        console.error('❌ Error removing old completion days:', err);
        return 0;
    }
};
const runDailyCleanup = async () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    console.log('🧹 Starting daily task cleanup...');
    try {
        const archivedCount = await archiveCompletedTasks();
        const deletedCount = await deleteOldArchivedTasks();
        const cleanedCount = await removeOldCompletionDays();
        const result = {
            archivedTasks: archivedCount,
            deletedAndPreservedTasks: deletedCount,
            cleanedTasks: cleanedCount,
            processedDate: today.toDateString(),
            timestamp: now.toISOString(),
            status: 'success',
        };
        console.log('✅ Daily cleanup completed:', result);
        return result;
    }
    catch (err) {
        console.error('❌ Daily cleanup failed:', err);
        return {
            archivedTasks: 0,
            deletedAndPreservedTasks: 0,
            cleanedTasks: 0,
            processedDate: today.toDateString(),
            timestamp: now.toISOString(),
            status: 'failed',
            error: err.message,
        };
    }
};
exports.runDailyCleanup = runDailyCleanup;
const runManualCleanup = async () => {
    console.log('🔧 Running manual cleanup...');
    return (0, exports.runDailyCleanup)();
};
exports.runManualCleanup = runManualCleanup;
