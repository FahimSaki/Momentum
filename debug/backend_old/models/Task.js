import mongoose from 'mongoose';

const taskSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String },

    // assignment system
    assignedTo: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Changed to array for multiple assignees
    assignedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    team: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' }, // NEW: Link to team

    // Task properties
    priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
    dueDate: { type: Date }, // NEW: Due date for team tasks
    tags: [{ type: String, trim: true }], // NEW: Tags for organization

    // Completion tracking (updated for team tasks)
    completedDays: [{ type: Date }],
    completedBy: [{ // NEW: Track who completed it
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        completedAt: { type: Date, default: Date.now }
    }],
    lastCompletedDate: { type: Date },

    // Status tracking
    isArchived: { type: Boolean, default: false },
    archivedAt: { type: Date },

    // Team task specific
    isTeamTask: { type: Boolean, default: false },
    assignmentType: {
        type: String,
        enum: ['individual', 'multiple', 'team'],
        default: 'individual'
    },

    // Recurrence (for future feature)
    recurrence: {
        isRecurring: { type: Boolean, default: false },
        pattern: { type: String, enum: ['daily', 'weekly', 'monthly'] },
        interval: { type: Number, default: 1 }
    }
}, { timestamps: true });

// Indexes for efficient queries
taskSchema.index({ assignedTo: 1 });
taskSchema.index({ assignedBy: 1 });
taskSchema.index({ team: 1 });
taskSchema.index({ dueDate: 1 });
taskSchema.index({ isArchived: 1, team: 1 });

export default mongoose.model('Task', taskSchema);
