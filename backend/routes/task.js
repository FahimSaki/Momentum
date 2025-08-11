import express from 'express';
import {
    createTask,
    getAssignedTasks,
    updateTask,
    archiveCompletedTasks,
    deleteCompletedTasks,
    deleteOldArchivedTasks,
    removeOldCompletionDays,
    removeYesterdayCompletions,
    deleteTask,
    getTaskHistory
} from '../controllers/taskController.js';
import { runManualCleanup } from '../services/cleanup_scheduler.js';

const router = express.Router();

// CRUD operations
router.post('/', createTask);
router.get('/assigned', getAssignedTasks);
router.put('/:id', updateTask);
router.delete('/:id', deleteTask);

// Bulk operations
router.post('/archive-completed', archiveCompletedTasks);
router.delete('/completed', deleteCompletedTasks); // This is what your Flutter app calls
router.delete('/old-archived', deleteOldArchivedTasks);

// Cleanup operations
router.post('/remove-old-completions', removeOldCompletionDays);
router.post('/remove-yesterday-completions', removeYesterdayCompletions);

// History for heatmap
router.get('/history', getTaskHistory);

// 🔧 NEW: Manual cleanup route for testing/debugging
router.post('/manual-cleanup', async (req, res) => {
    try {
        console.log('🔧 Manual cleanup triggered by API call');
        await runManualCleanup();
        res.status(200).json({ message: 'Manual cleanup completed successfully' });
    } catch (error) {
        console.error('❌ Manual cleanup failed:', error);
        res.status(500).json({ message: 'Manual cleanup failed', error: error.message });
    }
});

export default router;