import mongoose from 'mongoose';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import User from '../models/User';

dotenv.config();

// Run once to add invite IDs to existing users that don't have one.
// Usage: npx ts-node src/scripts/addInviteIds.ts

async function addInviteIdsToExistingUsers(): Promise<void> {
    try {
        const uri = process.env.MONGODB_URI;
        if (!uri) throw new Error('MONGODB_URI not set in .env');

        await mongoose.connect(uri);
        console.log('✅ Connected to MongoDB');

        const usersWithout = await User.find({ inviteId: { $exists: false } });
        console.log(`Found ${usersWithout.length} users without invite IDs`);

        for (const user of usersWithout) {
            user.inviteId = randomUUID();

            if (!user.name) {
                user.name = 'Anonymous User';
            }

            user.isPublic = true;
            user.profileVisibility = {
                showEmail: false,
                showName: true,
                showBio: true,
            };

            await user.save();
            console.log(`✅ Added invite ID ${user.inviteId} to user ${user.email}`);
        }

        console.log('🎉 Migration complete!');
        process.exit(0);
    } catch (err) {
        console.error('❌ Migration error:', err);
        process.exit(1);
    }
}

addInviteIdsToExistingUsers();