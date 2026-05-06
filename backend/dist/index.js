"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const mongoose_1 = __importDefault(require("mongoose"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const path_1 = __importDefault(require("path"));
const dotenv_1 = __importDefault(require("dotenv"));
const dns_1 = __importDefault(require("dns"));
const notificationService_1 = require("./services/notificationService");
const schedulerService_1 = require("./services/schedulerService");
const cleanupScheduler_1 = require("./services/cleanupScheduler");
const auth_1 = __importDefault(require("./routes/auth"));
const tasks_1 = __importDefault(require("./routes/tasks"));
const teams_1 = __importDefault(require("./routes/teams"));
const users_1 = __importDefault(require("./routes/users"));
const notifications_1 = __importDefault(require("./routes/notifications"));
dotenv_1.default.config({ path: path_1.default.resolve(process.cwd(), '.env') });
dns_1.default.setServers(['8.8.8.8', '8.8.4.4']);
const app = (0, express_1.default)();
const PORT = process.env.PORT || 3000;
// ── Security & parsing ────────────────────────────────────────────────────
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*', credentials: true }));
app.use(express_1.default.json({ limit: '10mb' }));
app.use(express_1.default.urlencoded({ extended: true }));
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
        const result = await (0, cleanupScheduler_1.runManualCleanup)();
        res.json({ message: 'Manual cleanup completed', ...result });
    }
    catch (err) {
        res.status(500).json({ message: 'Cleanup failed', error: err.message });
    }
});
// ── API routes (no /api prefix — matches Flutter app expectations) ─────────
app.use('/auth', auth_1.default);
app.use('/tasks', tasks_1.default);
app.use('/teams', teams_1.default);
app.use('/users', users_1.default);
app.use('/notifications', notifications_1.default);
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
app.use((err, _req, res, _next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ message: 'Internal server error' });
});
// ── DB + Firebase + Scheduler + start ────────────────────────────────────
const startServer = async () => {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri)
        throw new Error('MONGODB_URI is required');
    await mongoose_1.default.connect(mongoUri, { serverSelectionTimeoutMS: 10000 });
    console.log('✅ MongoDB connected');
    (0, notificationService_1.initFirebase)();
    (0, schedulerService_1.startScheduler)();
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
exports.default = app;
//# sourceMappingURL=index.js.map