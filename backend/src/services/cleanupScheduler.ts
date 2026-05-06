import Task from '../models/Task';
import TaskHistory from '../models/TaskHistory';
import { ITaskDocument } from '../types/interfaces';

// ── Save task completions to history before deletion ──────────────────────

const saveTaskToHistory = async (task: ITaskDocument): Promise<void> => {
    if (!task.completedDays?.length) return;
    try {
        const existingHistory = await TaskHistory.findOne({
            userId: { $in: task.assignedTo },
            taskName: task.name,
        });
        if (existingHistory) {
            const allDays = [...existingHistory.completedDays, ...task.completedDays];
            const unique = [...new Set(allDays.map((d) => d.toISOString()))].map((d) => new Date(d));
            existingHistory.completedDays = unique;
            await existingHistory.save();
            console.log(`Updated history for "${task.name}"`);
        } else {
            for (const assigneeId of task.assignedTo) {
                await TaskHistory.create({
                    userId: assigneeId,
                    completedDays: task.completedDays,
                    taskName: task.name,
                    teamId: task.team,
                });
            }
            console.log(`Saved task "${task.name}" to history`);
        }
    } catch (err) {
        console.error(`Error saving task "${task.name}" to history:`, err);
    }
};

// ── Step 1: Archive tasks completed before today ──────────────────────────

const archiveCompletedTasks = async (): Promise<number> => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const result = await Task.updateMany(
            { isArchived: false, lastCompletedDate: { $lt: today } },
            { $set: { isArchived: true, archivedAt: new Date() } }
        );

        console.log(`✅ Archived ${result.modifiedCount} tasks completed before ${today.toDateString()}`);
        return result.modifiedCount;
    } catch (err) {
        console.error('❌ Error archiving completed tasks:', err);
        return 0;
    }
};

// ── Step 2: Delete old archived tasks and preserve history ────────────────

const deleteOldArchivedTasks = async (): Promise<number> => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        const tasksToDelete = await Task.find({
            isArchived: true,
            archivedAt: { $lt: today },
        });

        console.log(`Found ${tasksToDelete.length} archived tasks to delete`);
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
        console.error('❌ Error deleting old archived tasks:', err);
        return 0;
    }
};

// ── Step 3: Clean old completion days from active tasks ───────────────────

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
                    // Save old completions to history before removing
                    const taskWithOldData = { ...task.toObject(), completedDays: oldCompletions } as ITaskDocument;
                    await saveTaskToHistory(taskWithOldData);
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

// ── Main daily cleanup ────────────────────────────────────────────────────

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
    console.log(`📅 Today: ${today.toDateString()}`);

    try {
        console.log('📦 Step 1: Archiving tasks completed before today...');
        const archivedCount = await archiveCompletedTasks();

        console.log('🗑️  Step 2: Deleting old archived tasks...');
        const deletedCount = await deleteOldArchivedTasks();

        console.log('🧽 Step 3: Cleaning old completion days...');
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

// ── Manual cleanup (for testing / admin endpoint) ─────────────────────────

export const runManualCleanup = async (): Promise<CleanupResult> => {
    console.log('🔧 Running manual cleanup...');
    const result = await runDailyCleanup();
    console.log('✅ Manual cleanup finished:', result);
    return result;
};