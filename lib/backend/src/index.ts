import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

import connectDB from './config/db';
import authRoutes from './routes/auth';
import taskRoutes from './routes/task';
import healthRoutes from './routes/health';

dotenv.config();
connectDB();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/v1', healthRoutes);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
