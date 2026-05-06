"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const crypto_1 = require("crypto");
const dotenv_1 = __importDefault(require("dotenv"));
const User_1 = __importDefault(require("../models/User"));
dotenv_1.default.config();
// Run once to add invite IDs to existing users that don't have one.
// Usage: npx ts-node src/scripts/addInviteIds.ts
async function addInviteIdsToExistingUsers() {
    try {
        const uri = process.env.MONGODB_URI;
        if (!uri)
            throw new Error('MONGODB_URI not set in .env');
        await mongoose_1.default.connect(uri);
        console.log('✅ Connected to MongoDB');
        const usersWithout = await User_1.default.find({ inviteId: { $exists: false } });
        console.log(`Found ${usersWithout.length} users without invite IDs`);
        for (const user of usersWithout) {
            user.inviteId = (0, crypto_1.randomUUID)();
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
    }
    catch (err) {
        console.error('❌ Migration error:', err);
        process.exit(1);
    }
}
addInviteIdsToExistingUsers();
//# sourceMappingURL=addInviteIds.js.map