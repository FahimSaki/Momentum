import express from 'express';
import { createHabit, getAssignedHabits } from '../controllers/habitController.js';
const router = express.Router();

router.post('/', createHabit);
router.get('/assigned', getAssignedHabits);

// TODO: Add habit CRUD and assignment routes

export default router;
