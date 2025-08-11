import mongoose from 'mongoose';

const taskHistorySchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    taskName: { type: String, required: true },
    completedDays: [{ type: Date }]
}, { timestamps: true });

export default mongoose.model('TaskHistory', taskHistorySchema);
