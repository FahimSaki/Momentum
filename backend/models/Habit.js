import mongoose from 'mongoose';

const habitSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String },
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assignedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    completedDays: [{ type: Date }],
    lastCompletedDate: { type: Date },
    isArchived: { type: Boolean, default: false },
    archivedAt: { type: Date },
}, { timestamps: true });

export default mongoose.model('Habit', habitSchema);
