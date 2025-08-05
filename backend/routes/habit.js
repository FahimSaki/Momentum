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
router.get('/history', getHabitHistory); // Note: This should be /habits/history in your app

export default router;