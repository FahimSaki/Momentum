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
// CORS setup: allow production, preview, and local dev frontends
app.use(cors({
    origin: function (origin, callback) {
        const allowedOrigins = [
            'https://momentum-beryl-nine.vercel.app', // Vercel production
            'http://localhost:10000', // Local backend
            undefined, // Postman, curl, etc.
        ];

        // Allow all Vercel preview URLs (e.g., *.vercel.app)
        if (
            allowedOrigins.includes(origin) ||
            (origin && origin.endsWith('.vercel.app'))
        ) {
            callback(null, true);
        } else {
            console.warn(`Blocked CORS origin: ${origin}`);
            callback(new Error('Not allowed by CORS: ' + origin));
        }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
    credentials: true,
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
