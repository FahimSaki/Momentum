import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import dotenv from 'dotenv';
import dns from 'dns';

import { initFirebase } from './services/notificationService';
import { startScheduler } from './services/schedulerService';
import { runManualCleanup } from './services/cleanupScheduler';

import authRoutes from './routes/auth';
import taskRoutes from './routes/tasks';
import teamRoutes from './routes/teams';
import userRoutes from './routes/users';
import notificationRoutes from './routes/notifications';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dns.setServers(['8.8.8.8', '8.8.4.4']);

const app = express();
const PORT = process.env.PORT || 3000;

// ── Security & parsing ────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*', credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Request logging ───────────────────────────────────────────────────────
app.use((req, _res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

// ── Public routes ─────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString(), uptime: process.uptime() });
});

app.get('/wake-up', (_req, res) => {
    res.json({ message: 'Server is awake', timestamp: new Date().toISOString(), uptime: process.uptime() });
});

app.post('/manual-cleanup', async (_req, res) => {
    try {
        const result = await runManualCleanup();
        res.json({ message: 'Manual cleanup completed', ...result });
    } catch (err: any) {
        res.status(500).json({ message: 'Cleanup failed', error: err.message });
    }
});

// ── API routes (no /api prefix — matches Flutter app expectations) ─────────
app.use('/auth', authRoutes);
app.use('/tasks', taskRoutes);
app.use('/teams', teamRoutes);
app.use('/users', userRoutes);
app.use('/notifications', notificationRoutes);
app.get('/', (_req, res) => {
    res.json({
        status: 'ok',
        message: 'Momentum API is running 🚀',
        health: '/health'
    });
});

// ── 404 ───────────────────────────────────────────────────────────────────
app.use((req, res) => {
    console.log(`404: ${req.method} ${req.originalUrl}`);
    res.status(404).json({ message: 'Route not found', method: req.method, url: req.originalUrl });
});

// ── Global error handler ──────────────────────────────────────────────────
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ message: 'Internal server error' });
});

// ── DB + Firebase + Scheduler + start ────────────────────────────────────
const startServer = async (): Promise<void> => {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) throw new Error('MONGODB_URI is required');

    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 10000 });
    console.log('✅ MongoDB connected');

    initFirebase();
    startScheduler();

    app.listen(PORT, () => {
        console.log(`🚀 Server running on port ${PORT}`);
        console.log(`   NODE_ENV : ${process.env.NODE_ENV ?? 'development'}`);
        console.log(`   Health   : http://localhost:${PORT}/health`);
    });
};

startServer().catch((err) => {
    console.error('❌ Failed to start:', err);
    process.exit(1);
});

export default app;