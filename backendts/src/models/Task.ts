import mongoose, { Schema } from 'mongoose';
import { ITaskDocument } from '../types/interfaces';

const taskSchema = new Schema<ITaskDocument>(
    {
        name: { type: String, required: true },
        description: { type: String },
        assignedTo: [{ type: Schema.Types.ObjectId, ref: 'User' }],
        assignedBy: { type: Schema.Types.ObjectId, ref: 'User' },
        team: { type: Schema.Types.ObjectId, ref: 'Team' },
        priority: {
            type: String,
            enum: ['low', 'medium', 'high', 'urgent'],
            default: 'medium',
        },
        dueDate: { type: Date },
        tags: [{ type: String, trim: true }],
        completedDays: [{ type: Date }],
        completedBy: [
            {
                user: { type: Schema.Types.ObjectId, ref: 'User' },
                completedAt: { type: Date, default: Date.now },
            },
        ],
        lastCompletedDate: { type: Date },
        isArchived: { type: Boolean, default: false },
        archivedAt: { type: Date },
        isTeamTask: { type: Boolean, default: false },
        assignmentType: {
            type: String,
            enum: ['individual', 'multiple', 'team'],
            default: 'individual',
        },
        recurrence: {
            isRecurring: { type: Boolean, default: false },
            pattern: { type: String, enum: ['daily', 'weekly', 'monthly'] },
            interval: { type: Number, default: 1 },
        },
    },
    { timestamps: true }
);

taskSchema.index({ assignedTo: 1 });
taskSchema.index({ assignedBy: 1 });
taskSchema.index({ team: 1 });
taskSchema.index({ dueDate: 1 });
taskSchema.index({ isArchived: 1, team: 1 });

export default mongoose.model<ITaskDocument>('Task', taskSchema);