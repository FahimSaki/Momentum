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
import dns from 'dns';

// Load environment variables
dotenv.config();
dns.setServers(['8.8.8.8', '8.8.4.4']);

const app = express();
app.use(express.json());

/* ================================
   REQUEST LOGGING MIDDLEWARE
================================ */
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    console.log('Headers:', JSON.stringify(req.headers, null, 2));

    if (req.body && Object.keys(req.body).length > 0) {
        console.log('Body:', JSON.stringify(req.body, null, 2));
    }

    console.log('---');
    next();
});

/* ================================
   CORS CONFIG
================================ */
app.use(cors({
    origin: function (origin, callback) {
        if (!origin) return callback(null, true);

        const allowedOrigins = [
            'https://momentum-beryl-nine.vercel.app',
            'http://localhost:10000',
            'http://localhost:3000',
            'http://127.0.0.1:3000',
        ];

        if (allowedOrigins.includes(origin) || origin.endsWith('.vercel.app')) {
            callback(null, true);
        } else {
            console.warn(`CORS origin allowed (dev mode): ${origin}`);
            callback(null, true);
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
    optionsSuccessStatus: 200
}));

app.options('*', cors());

/* ================================
   DATABASE CONNECTION
================================ */
mongoose.connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    serverSelectionTimeoutMS: 10000,
})
    .then(() => {
        console.log('✅ MongoDB connected');
        startScheduler();
    })
    .catch(err => console.error('❌ MongoDB connection error:', err));

/* ================================
   PUBLIC ROUTES
================================ */
app.get('/wake-up', (req, res) => {
    const now = new Date();
    console.log('⏰ Wake-up ping received at:', now.toISOString());

    res.status(200).json({
        message: 'Server is awake',
        timestamp: now.toISOString(),
        uptime: process.uptime()
    });
});

app.post('/manual-cleanup', async (req, res) => {
    try {
        const startTime = new Date();
        console.log('🔧 Manual cleanup triggered:', startTime.toISOString());

        await runManualCleanup();

        const endTime = new Date();
        const duration = endTime - startTime;

        const response = {
            message: 'Manual cleanup completed successfully',
            timestamp: endTime.toISOString(),
            duration: `${duration}ms`,
            triggered_by: 'external_cron'
        };

        console.log('✅ Cleanup done:', response);
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

/* ================================
   AUTHENTICATED ROUTES
================================ */
app.use('/auth', authRoutes);
app.use('/tasks', authenticateToken, taskRoutes);
app.use('/teams', authenticateToken, teamRoutes);
app.use('/notifications', authenticateToken, notificationRoutes);
app.use('/users', authenticateToken, userRoutes);

/* ================================
   HEALTH CHECK
================================ */
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
});

app.get('/', (req, res) => {
    res.send('Momentum backend API running');
});

/* ================================
   ERROR HANDLER
================================ */
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);

    const isDevelopment = process.env.NODE_ENV === 'development';

    res.status(err.status || 500).json({
        message: err.message || 'Internal server error',
        ...(isDevelopment && {
            stack: err.stack,
            error: err
        })
    });
});

/* ================================
   404 HANDLER
================================ */
app.use('*', (req, res) => {
    console.log(`404 - Route not found: ${req.method} ${req.originalUrl}`);

    res.status(404).json({
        message: 'Route not found',
        method: req.method,
        url: req.originalUrl
    });
});

/* ================================
   START SERVER
================================ */
const PORT = process.env.PORT || 10000;

app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
});
