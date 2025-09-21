import User from '../models/User.js';
import Team from '../models/Team.js';

// Get current user profile
export const getUserProfile = async (req, res) => {
    try {
        const user = await User.findById(req.userId).select('-password');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.json(user);
    } catch (error) {
        console.error('Get user profile error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Search users for team invitations
export const searchUsers = async (req, res) => {
    try {
        const { query, limit = 20 } = req.query;
        const currentUserId = req.userId;

        if (!query || query.trim().length < 2) {
            return res.json([]);
        }

        const searchRegex = new RegExp(query.trim(), 'i');

        const users = await User.find({
            _id: { $ne: currentUserId },
            isPublic: true,
            $or: [
                { name: searchRegex },
                { email: searchRegex },
                { inviteId: searchRegex }
            ]
        })
            .select('name email inviteId avatar bio profileVisibility')
            .limit(parseInt(limit));

        res.json(users);
    } catch (error) {
        console.error('Search users error:', error);
        res.status(500).json({ message: 'Search failed', error: error.message });
    }
};

// Get user by invite ID
export const getUserByInviteId = async (req, res) => {
    try {
        const { inviteId } = req.params;

        const user = await User.findOne({
            inviteId,
            isPublic: true
        }).select('name email inviteId avatar bio profileVisibility');

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        res.json(user);
    } catch (error) {
        console.error('Get user by invite ID error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Update privacy settings
export const updatePrivacySettings = async (req, res) => {
    try {
        const { isPublic, profileVisibility } = req.body;

        const updatedUser = await User.findByIdAndUpdate(
            req.userId,
            {
                isPublic,
                profileVisibility
            },
            { new: true }
        ).select('-password');

        res.json(updatedUser);
    } catch (error) {
        console.error('Update privacy settings error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};