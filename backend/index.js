import express from 'express';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import taskRoutes from './routes/task.js';
import { authenticateToken } from './middleware/middle_auth.js';
import teamRoutes from './routes/team.js';
import notificationRoutes from './routes/notification.js';
import { runManualCleanup } from './services/cleanupScheduler.js';
import { startScheduler } from './services/schedulerService.js';
import userRoutes from './routes/user.js';

// Load environment variables
dotenv.config();

const app = express();
app.use(express.json());

// CORS setup: allow production, preview, and local dev frontends
app.use(cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin) return callback(null, true);

        const allowedOrigins = [
            'https://momentum-beryl-nine.vercel.app', // Vercel production
            'http://localhost:10000', // Local backend
            'http://localhost:3000',  // Local frontend
            'http://127.0.0.1:3000',  // Alternative localhost
        ];

        // Allow all Vercel preview URLs
        if (allowedOrigins.includes(origin) || origin.endsWith('.vercel.app')) {
            callback(null, true);
        } else {
            console.warn(`CORS origin logged but allowed: ${origin}`);
            // For mobile apps, allow all origins during development
            callback(null, true); // Change this to be more permissive
        }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: [
        'Content-Type',
        'Authorization',
        'Accept',
        'Origin',
        'X-Requested-With',
        'Access-Control-Allow-Headers',
        'Access-Control-Allow-Origin'
    ],
    credentials: true,
    optionsSuccessStatus: 200 // Some legacy browsers choke on 204
}));

// Add preflight handling
app.options('*', cors()); // Enable preflight for all routes

// Connect to MongoDB (cleaned up deprecated options)
mongoose.connect(process.env.MONGODB_URI)
    .then(() => {
        console.log('✅ MongoDB connected');

        // Cleanup Scheduler on top of the old scheduler
        startScheduler();
    })
    .catch(err => console.error('❌ MongoDB connection error:', err));

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

        await runManualCleanup();

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
// Request Logging Middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    console.log('Headers:', JSON.stringify(req.headers, null, 2));
    if (req.body && Object.keys(req.body).length > 0) {
        console.log('Body:', JSON.stringify(req.body, null, 2));
    }
    console.log('---');
    next();
});

// AUTHENTICATED ROUTES
app.use('/auth', authRoutes);
app.use('/tasks', authenticateToken, taskRoutes);
app.use('/teams', authenticateToken, teamRoutes);
app.use('/notifications', authenticateToken, notificationRoutes);
app.use('/users', authenticateToken, userRoutes);

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
});

// Request logging endpoint
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);

    // Don't leak error details in production
    const isDevelopment = process.env.NODE_ENV === 'development';

    res.status(err.status || 500).json({
        message: err.message || 'Internal server error',
        ...(isDevelopment && {
            stack: err.stack,
            error: err
        })
    });
})

// Handle 404s
app.use('*', (req, res) => {
    console.log(`404 - Route not found: ${req.method} ${req.originalUrl}`);
    res.status(404).json({
        message: 'Route not found',
        method: req.method,
        url: req.originalUrl
    });
});