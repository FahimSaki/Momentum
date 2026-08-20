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
        // Set only for tasks created through the offline sync queue (see
        // Flutter's TaskDatabase._flushPendingOperationsOnce). Lets
        // POST /tasks recognise a retried request — e.g. the client timed
        // out waiting for a response the server had actually already
        // finished producing — and return the existing task instead of
        // creating a second one.
        clientId: { type: String },
    },
    { timestamps: true }
);

taskSchema.index({ assignedTo: 1 });
taskSchema.index({ assignedBy: 1 });
taskSchema.index({ team: 1 });
taskSchema.index({ dueDate: 1 });
taskSchema.index({ isArchived: 1, team: 1 });
// `sparse` on a COMPOUND index only excludes a document missing ALL of the
// index's fields — every task has `assignedBy`, so this was indexing
// every task and colliding on the second one any user created without a
// clientId. `partialFilterExpression` only builds an index entry for
// documents that actually have a clientId, which is what was intended.
taskSchema.index(
    { assignedBy: 1, clientId: 1 },
    {
        unique: true,
        partialFilterExpression: { clientId: { $exists: true } },
    }
);

export default mongoose.model<ITaskDocument>('Task', taskSchema);