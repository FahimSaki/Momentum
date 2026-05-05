import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import dotenv from 'dotenv';
import dns from 'dns';

import { initFirebase } from './services/notificationService';

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

// ── Health check ──────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString(), uptime: process.uptime() });
});

// ── Routes ────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/users', userRoutes);
app.use('/api/notifications', notificationRoutes);

// ── 404 ───────────────────────────────────────────────────────────────────
app.use((_req, res) => {
    res.status(404).json({ message: 'Route not found' });
});

// ── Global error handler ──────────────────────────────────────────────────
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ message: 'Internal server error' });
});

// ── DB + Firebase + start ─────────────────────────────────────────────────
const startServer = async (): Promise<void> => {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) throw new Error('MONGODB_URI environment variable is required');

    await mongoose.connect(mongoUri);
    console.log('✅ MongoDB connected');

    initFirebase();

    app.listen(PORT, () => {
        console.log(`🚀 Server running on port ${PORT}`);
        console.log(`   Environment : ${process.env.NODE_ENV ?? 'development'}`);
        console.log(`   Health check: http://localhost:${PORT}/health`);
    });
};

startServer().catch((err) => {
    console.error('❌ Failed to start server:', err);
    process.exit(1);
});

export default app;