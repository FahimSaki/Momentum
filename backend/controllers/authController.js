import User from '../models/User.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

// TODO: Implement Google OAuth logic

export const login = async (req, res) => {
    try {
        console.log('=== LOGIN DEBUG ===');
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        console.log('==================');

        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ message: 'Email and password are required' });
        }

        const trimmedEmail = email.toLowerCase().trim();

        const user = await User.findOne({ email: trimmedEmail });
        if (!user) {
            console.log('User not found:', trimmedEmail);
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        if (!user.password) {
            console.log('User registered with Google:', trimmedEmail);
            return res.status(401).json({ message: 'User registered with Google. Use Google login.' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            console.log('Password mismatch for:', trimmedEmail);
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        // Update last login
        user.lastLoginAt = new Date();
        await user.save();

        const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });

        // Remove password from response
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

        console.log('Login successful for:', trimmedEmail);
        res.json({
            token,
            user: userResponse,
            message: 'Login successful'
        });

    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

export const register = async (req, res) => {
    try {
        console.log('=== REGISTRATION DEBUG ===');
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        console.log('Headers:', JSON.stringify(req.headers, null, 2));
        console.log('=========================');

        const { email, password, name } = req.body;

        // Enhanced validation
        if (!email || !email.trim()) {
            return res.status(400).json({ message: 'Email is required' });
        }

        if (!password || password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters long' });
        }

        const trimmedEmail = email.toLowerCase().trim();

        // Check if user already exists
        let user = await User.findOne({ email: trimmedEmail });
        if (user) {
            console.log('User already exists:', trimmedEmail);
            return res.status(400).json({ message: 'User already exists' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user with proper name handling
        user = new User({
            email: trimmedEmail,
            password: hashedPassword,
            name: name?.trim() || trimmedEmail.split('@')[0], // Use email prefix if no name
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

        // Remove password from response
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

        // Handle MongoDB duplicate key error
        if (err.code === 11000) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Handle validation errors
        if (err.name === 'ValidationError') {
            const validationErrors = Object.values(err.errors).map(e => e.message);
            return res.status(400).json({
                message: 'Validation error',
                errors: validationErrors
            });
        }

        res.status(500).json({
            message: 'Server error during registration',
            error: err.message
        });
    }
};
