//!  RUN THIS ONCE to add invite IDs to existing users
//? cd backend
//? node scripts/addInviteIds.js

import mongoose from 'mongoose';
import User from '../models/User.js';
import dotenv from 'dotenv';
import { randomUUID } from 'crypto';

dotenv.config();

// RUN THIS ONCE to add invite IDs to existing users
async function addInviteIdsToExistingUsers() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // Find users without invite IDs
        const usersWithoutInviteId = await User.find({ inviteId: { $exists: false } });

        console.log(`Found ${usersWithoutInviteId.length} users without invite IDs`);

        for (const user of usersWithoutInviteId) {
            // Generate invite ID using Node.js built-in crypto module
            user.inviteId = randomUUID();

            // Set a default name if it doesn't exist
            if (!user.name) {
                user.name = "Anonymous User";
            }

            // Set default privacy settings
            user.isPublic = true;
            user.profileVisibility = {
                showEmail: false,
                showName: true,
                showBio: true
            };

            // Mark the fields as modified to ensure Mongoose saves them
            user.markModified('inviteId');
            user.markModified('name');
            user.markModified('isPublic');
            user.markModified('profileVisibility');

            await user.save();
            console.log(`Added invite ID ${user.inviteId} for user ${user.name}`);
        }

        console.log('Migration complete!');
        process.exit(0);
    } catch (error) {
        console.error('Migration error:', error);
        process.exit(1);
    }
}

addInviteIdsToExistingUsers();