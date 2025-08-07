// File: routes/habitRoutes.js
import express from 'express';
import {
    createHabit,
    getAssignedHabits,
    updateHabit,
    archiveCompletedHabits,
    deleteCompletedHabits,
    deleteOldArchivedHabits,
    removeOldCompletionDays,
    removeYesterdayCompletions,
    deleteHabit,
    getHabitHistory
} from '../controllers/habitController.js';
import { runManualCleanup } from '../services/cleanup_scheduler.js';

const router = express.Router();

// CRUD operations
router.post('/', createHabit);
router.get('/assigned', getAssignedHabits);
router.put('/:id', updateHabit);
router.delete('/:id', deleteHabit);

// Bulk operations
router.post('/archive-completed', archiveCompletedHabits);
router.delete('/completed', deleteCompletedHabits); // This is what your Flutter app calls
router.delete('/old-archived', deleteOldArchivedHabits);

// Cleanup operations
router.post('/remove-old-completions', removeOldCompletionDays);
router.post('/remove-yesterday-completions', removeYesterdayCompletions);

// History for heatmap
router.get('/history', getHabitHistory);

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