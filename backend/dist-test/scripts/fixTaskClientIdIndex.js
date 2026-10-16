"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const dotenv_1 = __importDefault(require("dotenv"));
const Task_1 = __importDefault(require("../models/Task"));
dotenv_1.default.config();
// One-time fix for the broken assignedBy_1_clientId_1 index — see
// models/Task.ts for why the old `sparse: true` version was wrong.
// Must be run with the corrected Task.ts already in place, since
// syncIndexes() below rebuilds from whatever schema is currently imported.
// Usage: npx ts-node src/scripts/fixTaskClientIdIndex.ts
async function fixTaskClientIdIndex() {
    try {
        const uri = process.env.MONGODB_URI;
        if (!uri)
            throw new Error('MONGODB_URI not set in .env');
        await mongoose_1.default.connect(uri);
        console.log('✅ Connected to MongoDB');
        try {
            await Task_1.default.collection.dropIndex('assignedBy_1_clientId_1');
            console.log('🗑️  Dropped stale assignedBy_1_clientId_1 index');
        }
        catch (err) {
            if (err.codeName === 'IndexNotFound') {
                console.log('ℹ️  No stale index found — nothing to drop');
            }
            else {
                throw err;
            }
        }
        console.log('🔧 Rebuilding indexes from the current schema...');
        await Task_1.default.syncIndexes();
        const current = await Task_1.default.collection.indexes();
        console.log('✅ Current indexes:', JSON.stringify(current, null, 2));
        console.log('🎉 Done!');
        process.exit(0);
    }
    catch (err) {
        console.error('❌ Fix error:', err);
        process.exit(1);
    }
}
fixTaskClientIdIndex();
