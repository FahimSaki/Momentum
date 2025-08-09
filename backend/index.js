import express from 'express';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import habitRoutes from './routes/habit.js';
import { authenticateToken } from './middleware/middle_auth.js';
import { startCleanupScheduler, runManualCleanup } from './services/cleanup_scheduler.js';

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
    .then(() => {
        console.log('✅ MongoDB connected');

        // 🔧 NEW: Start the cleanup scheduler after DB connection
        startCleanupScheduler();
    })
    .catch(err => console.error('❌ MongoDB connection error:', err));

// 🔧 PUBLIC ROUTES (no authentication required) - MOVED HERE
// Public wake-up endpoint
app.get('/wake-up', (req, res) => {
    const now = new Date();
    console.log('⏰ Wake-up ping received at:', now.toISOString());
    res.status(200).json({
        message: 'Server is awake',
        timestamp: now.toISOString(),
        uptime: process.uptime()
    });
});

// Public cleanup endpoint  
app.post('/manual-cleanup', async (req, res) => {
    try {
        const startTime = new Date();
        console.log('🔧 Manual cleanup triggered by external cron service at:', startTime.toISOString());

        await runManualCleanup(); // 🔧 Now properly imported

        const endTime = new Date();
        const duration = endTime - startTime;

        const response = {
            message: 'Manual cleanup completed successfully',
            timestamp: endTime.toISOString(),
            duration: `${duration}ms`,
            triggered_by: 'external_cron'
        };

        console.log('✅ Manual cleanup response:', response);
        res.status(200).json(response);
    } catch (error) {
        console.error('❌ Manual cleanup failed:', error);
        res.status(500).json({
            message: 'Manual cleanup failed',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// AUTHENTICATED ROUTES
app.use('/auth', authRoutes);
app.use('/habits', authenticateToken, habitRoutes);

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
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log('📅 Automatic habit cleanup scheduler is active');
});