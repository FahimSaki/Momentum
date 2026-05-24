import Task from '../models/Task';
import { saveTaskToHistory } from '../helpers/taskHelpers';
import { ITaskDocument } from '../types/interfaces';

const archiveCompletedTasks = async (): Promise<number> => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const result = await Task.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );
        console.log(`✅ Archived ${result.modifiedCount} tasks`);
        return result.modifiedCount;
    } catch (err) {
        console.error('❌ Error archiving tasks:', err);
        return 0;
    }
};

const deleteOldArchivedTasks = async (): Promise<number> => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const tasksToDelete = await Task.find({ isArchived: true, archivedAt: { $lt: today } });
        let count = 0;
        for (const task of tasksToDelete) {
            try {
                await saveTaskToHistory(task);
                await task.deleteOne();
                count++;
            } catch (err) {
                console.error(`Error processing task "${task.name}":`, err);
            }
        }
        console.log(`✅ Deleted ${count} tasks, history preserved`);
        return count;
    } catch (err) {
        console.error('❌ Error deleting archived tasks:', err);
        return 0;
    }
};

const removeOldCompletionDays = async (): Promise<number> => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const tasks = await Task.find({});
        let cleaned = 0;
        for (const task of tasks) {
            try {
                const oldCompletions = task.completedDays.filter((d) => new Date(d) < today);
                if (oldCompletions.length > 0) {
                    await saveTaskToHistory({ ...task.toObject(), completedDays: oldCompletions } as ITaskDocument);
                }
                const before = task.completedDays.length;
                task.completedDays = task.completedDays.filter((d) => new Date(d) >= today);
                if (before !== task.completedDays.length) {
                    await task.save();
                    cleaned++;
                }
            } catch (err) {
                console.error(`Error cleaning task "${task.name}":`, err);
            }
        }
        console.log(`✅ Cleaned old completion days from ${cleaned} tasks`);
        return cleaned;
    } catch (err) {
        console.error('❌ Error removing old completion days:', err);
        return 0;
    }
};

export interface CleanupResult {
    archivedTasks: number;
    deletedAndPreservedTasks: number;
    cleanedTasks: number;
    processedDate: string;
    timestamp: string;
    status: 'success' | 'failed';
    error?: string;
}

export const runDailyCleanup = async (): Promise<CleanupResult> => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    console.log('🧹 Starting daily task cleanup...');
    try {
        const archivedCount = await archiveCompletedTasks();
        const deletedCount = await deleteOldArchivedTasks();
        const cleanedCount = await removeOldCompletionDays();
        const result: CleanupResult = {
            archivedTasks: archivedCount,
            deletedAndPreservedTasks: deletedCount,
            cleanedTasks: cleanedCount,
            processedDate: today.toDateString(),
            timestamp: now.toISOString(),
            status: 'success',
        };
        console.log('✅ Daily cleanup completed:', result);
        return result;
    } catch (err: any) {
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

export const runManualCleanup = async (): Promise<CleanupResult> => {
    console.log('🔧 Running manual cleanup...');
    return runDailyCleanup();
};