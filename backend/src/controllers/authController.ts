import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User';

export const login = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, password } = req.body as { email?: string; password?: string };

        if (!email || !password) {
            res.status(400).json({ message: 'Email and password are required' });
            return;
        }

        const trimmedEmail = email.toLowerCase().trim();
        const user = await User.findOne({ email: trimmedEmail }).lean();

        if (!user) {
            res.status(401).json({ message: 'Invalid email or password' });
            return;
        }

        if (!user.password) {
            res.status(401).json({
                message: 'This account uses Google Sign-In. Please use Google login.',
            });
            return;
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            res.status(401).json({ message: 'Invalid email or password' });
            return;
        }

        await User.findByIdAndUpdate(user._id, { lastLoginAt: new Date() }, { runValidators: false });

        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET as string, {
            expiresIn: '7d',
        });

        const userResponse = {
            _id: user._id,
            email: user.email,
            name: user.name,
            avatar: user.avatar,
            bio: user.bio,
            timezone: user.timezone,
            teams: user.teams,
            notificationSettings: user.notificationSettings,
            isActive: user.isActive,
            lastLoginAt: new Date(),
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
        };

        res.json({ token, user: userResponse, message: 'Login successful' });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ message: 'Server error during login' });
    }
};

export const register = async (req: Request, res: Response): Promise<void> => {
    try {
        const { email, password, name } = req.body as {
            email?: string;
            password?: string;
            name?: string;
        };

        if (!email?.trim()) {
            res.status(400).json({ message: 'Email is required for registration' });
            return;
        }
        if (!password || password.length < 6) {
            res.status(400).json({ message: 'Password must be at least 6 characters long' });
            return;
        }
        if (!name?.trim()) {
            res.status(400).json({ message: 'Name is required for registration' });
            return;
        }

        const trimmedEmail = email.toLowerCase().trim();
        const trimmedName = name.trim();

        const existingUser = await User.findOne({ email: trimmedEmail });
        if (existingUser) {
            res.status(400).json({
                message: 'An account with this email already exists. Please login instead.',
            });
            return;
        }

        const hashedPassword = await bcrypt.hash(password, 12);

        const user = new User({
            email: trimmedEmail,
            password: hashedPassword,
            name: trimmedName,
            isActive: true,
            lastLoginAt: new Date(),
            notificationSettings: {
                email: true,
                push: true,
                inApp: true,
                taskAssigned: true,
                taskCompleted: true,
                teamInvitations: true,
                dailyReminder: false,
            },
        });

        await user.save();

        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET as string, {
            expiresIn: '7d',
        });

        const userResponse = {
            _id: user._id,
            email: user.email,
            name: user.name,
            avatar: user.avatar,
            bio: user.bio,
            timezone: user.timezone,
            teams: user.teams,
            notificationSettings: user.notificationSettings,
            isActive: user.isActive,
            lastLoginAt: user.lastLoginAt,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
        };

        res.status(201).json({ token, user: userResponse, message: 'Registration successful' });
    } catch (err: any) {
        console.error('Registration error:', err);

        if (err.code === 11000) {
            res.status(400).json({ message: 'An account with this email already exists' });
            return;
        }
        if (err.name === 'ValidationError') {
            const errors = Object.values(err.errors).map((e: any) => e.message);
            res.status(400).json({ message: 'Validation failed', errors });
            return;
        }

        res.status(500).json({ message: 'Server error during registration' });
    }
};