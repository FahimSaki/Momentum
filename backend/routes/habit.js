import express from 'express';
import {
    createHabit,
    getAssignedHabits,
    removeOldCompletionDays,
    removeYesterdayCompletions,
    updateHabit,
    deleteHabit,
    archiveCompletedHabits,
    deleteOldArchivedHabits
} from '../controllers/habitController.js';

const router = express.Router();

router.post('/', createHabit);
router.get('/assigned', getAssignedHabits);
router.put('/:id', updateHabit);
router.delete('/:id', deleteHabit);

router.post('/remove-old-completions', removeOldCompletionDays);
router.post('/remove-yesterday-completions', removeYesterdayCompletions);

// ✅ New archive logic routes
router.post('/archive-completed', archiveCompletedHabits);
router.delete('/delete-archived', deleteOldArchivedHabits);

export default router;
