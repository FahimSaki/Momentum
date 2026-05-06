import mongoose, { Schema } from 'mongoose';
import { ITaskHistory } from '../types/interfaces';

const taskHistorySchema = new Schema<ITaskHistory>(
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

export default mongoose.model<ITaskHistory>('TaskHistory', taskHistorySchema);