import mongoose from 'mongoose';

const taskHistorySchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    taskName: { type: String, required: true },
    completedDays: [{ type: Date }],
    // ADD THE MISSING FIELD
    teamId: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' }
}, { timestamps: true });

// Add indexes for efficient queries
taskHistorySchema.index({ userId: 1 });
taskHistorySchema.index({ teamId: 1 });
taskHistorySchema.index({ userId: 1, taskName: 1 });

export default mongoose.model('TaskHistory', taskHistorySchema);