import mongoose, { Schema } from 'mongoose';
import { ITaskHistoryDocument } from '../types/interfaces';

const taskHistorySchema = new Schema<ITaskHistoryDocument>(
    {
        userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
        taskName: { type: String, required: true },
        completedDays: [{ type: Date }],
        teamId: { type: Schema.Types.ObjectId, ref: 'Team' },
    },
    { timestamps: true }
);

taskHistorySchema.index({ userId: 1 });
taskHistorySchema.index({ teamId: 1 });
taskHistorySchema.index({ userId: 1, taskName: 1 });

export default mongoose.model<ITaskHistoryDocument>('TaskHistory', taskHistorySchema);