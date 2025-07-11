import express from 'express';
import { createHabit, getAssignedHabits, removeOldCompletionDays, removeYesterdayCompletions, updateHabit, deleteHabit } from '../controllers/habitController.js';
const router = express.Router();

router.post('/', createHabit);
router.get('/assigned', getAssignedHabits);
router.put('/:id', updateHabit); // Add update route
router.delete('/:id', deleteHabit); // Add delete route
router.post('/remove-old-completions', removeOldCompletionDays);
router.post('/remove-yesterday-completions', removeYesterdayCompletions);

// TODO: Add habit CRUD and assignment routes

export default router;
