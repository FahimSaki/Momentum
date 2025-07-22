import mongoose from 'mongoose';

const habitHistorySchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    habitName: { type: String, required: true },
    completedDays: [{ type: Date }]
}, { timestamps: true });

export default mongoose.model('HabitHistory', habitHistorySchema);
