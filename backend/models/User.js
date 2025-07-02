import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String }, // Not required for Google users
    googleId: { type: String },
    name: { type: String },
    habitsAssigned: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Habit' }],
    fcmToken: { type: String }, // For push notifications
}, { timestamps: true });

export default mongoose.model('User', userSchema);
