import User from '../models/User.js';
import Team from '../models/Team.js';

// Get current user profile with better error handling
export const getUserProfile = async (req, res) => {
    try {
        console.log(`🔍 Getting profile for user: ${req.userId}`);

        const user = await User.findById(req.userId).select('-password');
        if (!user) {
            console.log(`❌ User not found: ${req.userId}`);
            return res.status(404).json({ message: 'User not found' });
        }

        // Ensure inviteId exists (for existing users who might not have one)
        if (!user.inviteId) {
            console.log(`⚠️ User ${user.email} has no invite ID, generating one...`);
            await user.save(); // This will trigger the pre-save middleware to generate inviteId
            console.log(`✅ Generated invite ID: ${user.inviteId} for user: ${user.email}`);
        }

        // Ensure profileVisibility exists
        if (!user.profileVisibility) {
            user.profileVisibility = {
                showEmail: false,
                showName: true,
                showBio: true
            };
            await user.save();
        }

        console.log(`✅ Profile loaded for user: ${user.email} (${user.inviteId})`);
        res.json(user);
    } catch (error) {
        console.error('Get user profile error:', error);
        res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
        });
    }
};

// Search users for team invitations with filtering
export const searchUsers = async (req, res) => {
    try {
        const { query, limit = 20 } = req.query;
        const currentUserId = req.userId;

        console.log(`🔍 User search: "${query}" by user: ${currentUserId}`);

        // Validate query length
        if (!query || typeof query !== 'string' || query.trim().length < 2) {
            console.log('⚠️ Search query too short or invalid');
            return res.json([]); // Return empty array, not error
        }

        // Use the static method with proper error handling
        try {
            const users = await User.searchUsers(query.trim(), parseInt(limit), currentUserId);

            // Filter results based on privacy settings
            const filteredUsers = users.map(user => {
                const userObj = user.toObject();

                // Always include name and inviteId for search results
                const result = {
                    _id: userObj._id,
                    name: userObj.name,
                    inviteId: userObj.inviteId,
                    avatar: userObj.avatar,
                    profileVisibility: userObj.profileVisibility
                };

                // Conditionally include email and bio based on privacy settings
                if (userObj.profileVisibility?.showEmail) {
                    result.email = userObj.email;
                }

                if (userObj.profileVisibility?.showBio && userObj.bio) {
                    result.bio = userObj.bio;
                }

                return result;
            });

            console.log(`✅ Search returned ${filteredUsers.length} results`);
            res.json(filteredUsers);
        } catch (searchError) {
            console.error('Search users static method error:', searchError);
            // Return empty array instead of error for better UX
            res.json([]);
        }
    } catch (error) {
        console.error('Search users error:', error);
        // Return empty array instead of 500 error
        res.json([]);
    }
};

// Get user by invite ID with error handling
export const getUserByInviteId = async (req, res) => {
    try {
        const { inviteId } = req.params;

        console.log(`🔍 Looking up user by invite ID: ${inviteId}`);

        if (!inviteId || inviteId.trim().length === 0) {
            return res.status(400).json({ message: 'Invalid invite ID provided' });
        }

        // Use the static method with proper error handling
        try {
            const user = await User.findByInviteId(inviteId.trim());

            if (!user) {
                console.log(`❌ User not found with invite ID: ${inviteId}`);
                return res.status(404).json({ message: 'User not found with that invite ID' });
            }

            // Filter response based on privacy settings
            const response = {
                _id: user._id,
                name: user.name,
                inviteId: user.inviteId,
                avatar: user.avatar,
                profileVisibility: user.profileVisibility
            };

            if (user.profileVisibility?.showEmail) {
                response.email = user.email;
            }

            if (user.profileVisibility?.showBio && user.bio) {
                response.bio = user.bio;
            }

            console.log(`✅ Found user: ${user.name} (${user.inviteId})`);
            res.json(response);
        } catch (findError) {
            console.log(`❌ Error finding user with invite ID: ${inviteId}`, findError);
            return res.status(404).json({
                message: findError.message || 'User not found with that invite ID'
            });
        }
    } catch (error) {
        console.error('Get user by invite ID error:', error);
        res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
        });
    }
};

// Update privacy settings with validation
export const updatePrivacySettings = async (req, res) => {
    try {
        const { isPublic, profileVisibility } = req.body;

        console.log(`🔧 Updating privacy settings for user: ${req.userId}`);
        console.log('New settings:', { isPublic, profileVisibility });

        // Validate input
        if (typeof isPublic !== 'boolean') {
            return res.status(400).json({ message: 'isPublic must be a boolean' });
        }

        if (!profileVisibility || typeof profileVisibility !== 'object') {
            return res.status(400).json({ message: 'profileVisibility must be an object' });
        }

        // Validate profileVisibility structure
        const validVisibilityKeys = ['showEmail', 'showName', 'showBio'];
        const visibilityKeys = Object.keys(profileVisibility);

        for (const key of visibilityKeys) {
            if (!validVisibilityKeys.includes(key)) {
                return res.status(400).json({ message: `Invalid visibility key: ${key}` });
            }
            if (typeof profileVisibility[key] !== 'boolean') {
                return res.status(400).json({ message: `${key} must be a boolean` });
            }
        }

        const updatedUser = await User.findByIdAndUpdate(
            req.userId,
            {
                isPublic,
                profileVisibility: {
                    showEmail: profileVisibility.showEmail ?? false,
                    showName: profileVisibility.showName ?? true,
                    showBio: profileVisibility.showBio ?? true
                }
            },
            { new: true, runValidators: true }
        ).select('-password');

        if (!updatedUser) {
            return res.status(404).json({ message: 'User not found' });
        }

        console.log(`✅ Privacy settings updated for user: ${updatedUser.email}`);
        res.json(updatedUser);
    } catch (error) {
        console.error('Update privacy settings error:', error);
        res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
        });
    }
};

// Get user stats (teams, tasks, etc.)
export const getUserStats = async (req, res) => {
    try {
        const userId = req.params.userId || req.userId;

        // Only allow users to see their own stats unless admin
        if (userId !== req.userId) {
            return res.status(403).json({ message: 'Access denied' });
        }

        const user = await User.findById(userId).populate('teams');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const stats = {
            teamsCount: user.teams?.length || 0,
            joinedDate: user.createdAt,
            lastLogin: user.lastLoginAt,
            isPublic: user.isPublic
        };

        res.json(stats);
    } catch (error) {
        console.error('Get user stats error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Update user profile (name, bio, avatar)
export const updateUserProfile = async (req, res) => {
    try {
        const { name, bio, avatar } = req.body;

        const updateData = {};
        if (name && name.trim().length > 0) {
            updateData.name = name.trim();
        }
        if (bio !== undefined) {
            updateData.bio = bio.trim().length > 0 ? bio.trim() : null;
        }
        if (avatar !== undefined) {
            updateData.avatar = avatar.trim().length > 0 ? avatar.trim() : null;
        }

        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({ message: 'No valid fields to update' });
        }

        const updatedUser = await User.findByIdAndUpdate(
            req.userId,
            updateData,
            { new: true, runValidators: true }
        ).select('-password');

        console.log(`✅ Profile updated for user: ${updatedUser.email}`);
        res.json(updatedUser);
    } catch (error) {
        console.error('Update user profile error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};