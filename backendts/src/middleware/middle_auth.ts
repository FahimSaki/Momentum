import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/User';
import { JwtPayload } from '../types/interfaces';

export const authenticateToken = async (
    req: Request,
    res: Response,
    next: NextFunction
): Promise<void> => {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.split(' ')[1];

    if (!token) {
        res.status(401).json({ message: 'Access token required' });
        return;
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload;
        const user = await User.findById(decoded.userId);

        if (!user) {
            res.status(401).json({ message: 'Invalid token – user not found' });
            return;
        }

        req.user = user;
        req.userId = user._id.toString();
        next();
    } catch (error) {
        console.error('Token verification error:', error);
        res.status(403).json({ message: 'Invalid or expired token' });
    }
};