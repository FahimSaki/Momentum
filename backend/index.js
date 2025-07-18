import express from 'express';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import habitRoutes from './routes/habit.js';

// Load environment variables
dotenv.config();

const app = express();
app.use(express.json());
app.use(cors({
    origin: function (origin, callback) {
        const allowedOrigins = [
            'https://momentum.vercel.app',
            'http://localhost:10000',
            undefined, // for mobile apps (no origin header)
        ];
        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
}));


// Connect to MongoDB (cleaned up deprecated options)
mongoose.connect(process.env.MONGODB_URI)
    .then(() => console.log('✅ MongoDB connected'))
    .catch(err => console.error('❌ MongoDB connection error:', err));

// Routes
app.use('/auth', authRoutes);
app.use('/habits', habitRoutes);

// Health check (optional, helpful for monitoring)
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
});

// Root endpoint
app.get('/', (req, res) => {
    res.send('Momentum backend API running');
});

// Start server
const PORT = process.env.PORT || 10000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
