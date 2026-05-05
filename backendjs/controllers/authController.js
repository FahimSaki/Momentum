// backend/controllers/authController.js - PROPER IMPLEMENTATION

import User from '../models/User.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

// LOGIN - Only requires email and password
export const login = async (req, res) => {
    try {
        console.log('=== LOGIN DEBUG ===');
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        console.log('==================');

        const { email, password } = req.body;

        // Validation - ONLY email and password needed for login
        if (!email || !password) {
            return res.status(400).json({
                message: 'Email and password are required for login'
            });
        }

        const trimmedEmail = email.toLowerCase().trim();

        // Find existing user (no validation should occur here)
        const user = await User.findOne({ email: trimmedEmail }).lean();
        if (!user) {
            console.log('User not found:', trimmedEmail);
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        // Check if user was registered with Google
        if (!user.password) {
            console.log('User registered with Google:', trimmedEmail);
            return res.status(401).json({
                message: 'This account uses Google Sign-In. Please use Google login.'
            });
        }

        // Verify password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            console.log('Password mismatch for:', trimmedEmail);
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        // Update last login (separately to avoid validation issues)
        await User.findByIdAndUpdate(user._id, {
            lastLoginAt: new Date()
        }, { runValidators: false });

        // Generate JWT
        const token = jwt.sign(
            { userId: user._id },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        // Prepare clean user response (remove sensitive data)
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
            updatedAt: user.updatedAt
        };

        console.log('Login successful for:', trimmedEmail);
        res.json({
            token,
            user: userResponse,
            message: 'Login successful'
        });

    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({
            message: 'Server error during login',
            error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
        });
    }
};

// REGISTER - Requires name, email, and password
export const register = async (req, res) => {
    try {
        console.log('=== REGISTRATION DEBUG ===');
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        console.log('=========================');

        const { email, password, name } = req.body;

        // Validation - ALL THREE fields required for registration
        if (!email || !email.trim()) {
            return res.status(400).json({ message: 'Email is required for registration' });
        }

        if (!password || password.length < 6) {
            return res.status(400).json({
                message: 'Password must be at least 6 characters long'
            });
        }

        if (!name || !name.trim()) {
            return res.status(400).json({
                message: 'Name is required for registration'
            });
        }

        const trimmedEmail = email.toLowerCase().trim();
        const trimmedName = name.trim();

        // Check if user already exists
        const existingUser = await User.findOne({ email: trimmedEmail });
        if (existingUser) {
            console.log('User already exists:', trimmedEmail);
            return res.status(400).json({
                message: 'An account with this email already exists. Please login instead.'
            });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 12);

        // Create new user with all required fields
        const user = new User({
            email: trimmedEmail,
            password: hashedPassword,
            name: trimmedName, // Name is required for registration
            isActive: true,
            lastLoginAt: new Date(),
            notificationSettings: {
                email: true,
                push: true,
                inApp: true,
                taskAssigned: true,
                taskCompleted: true,
                teamInvitations: true,
                dailyReminder: false
            }
        });

        await user.save();
        console.log('User created successfully:', user._id);

        // Generate JWT token
        const token = jwt.sign(
            { userId: user._id },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        // Prepare clean user response (remove password)
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
            updatedAt: user.updatedAt
        };

        console.log('Registration successful for:', trimmedEmail);
        res.status(201).json({
            token,
            user: userResponse,
            message: 'Registration successful'
        });

    } catch (err) {
        console.error('Registration error:', err);

        // Handle specific MongoDB errors
        if (err.code === 11000) {
            return res.status(400).json({
                message: 'An account with this email already exists'
            });
        }

        // Handle validation errors
        if (err.name === 'ValidationError') {
            const validationErrors = Object.values(err.errors).map(e => e.message);
            return res.status(400).json({
                message: 'Registration validation failed',
                errors: validationErrors
            });
        }

        res.status(500).json({
            message: 'Server error during registration',
            error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
        });
    }
};