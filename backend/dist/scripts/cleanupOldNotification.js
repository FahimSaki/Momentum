"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const Notification_1 = __importDefault(require("../models/Notification"));
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
dotenv_1.default.config({ path: path_1.default.resolve(process.cwd(), '.env') });
// Usage: npx ts-node src/scripts/cleanupOldNotification.ts [daysOld]
// Example: npx ts-node src/scripts/cleanupOldNotification.ts 30
async function cleanupOldNotifications() {
    try {
        const daysOld = parseInt(process.argv[2] || '30', 10);
        const uri = process.env.MONGODB_URI;
        if (!uri)
            throw new Error('MONGODB_URI not set in .env');
        await mongoose_1.default.connect(uri);
        console.log('✅ Connected to MongoDB\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🗑️  OLD NOTIFICATIONS CLEANUP');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        const cutoffDate = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);
        console.log(`📅 Cutoff date: ${cutoffDate.toISOString()}`);
        console.log(`   (Notifications older than ${daysOld} days)\n`);
        // 1. Count notifications to be deleted
        const toDeleteCount = await Notification_1.default.countDocuments({
            createdAt: { $lt: cutoffDate },
            isRead: true,
        });
        if (toDeleteCount === 0) {
            console.log('✅ No old notifications to clean up!\n');
            await mongoose_1.default.disconnect();
            process.exit(0);
        }
        console.log(`🔍 Found ${toDeleteCount} old read notifications to delete\n`);
        // 2. Get type breakdown before deletion
        const typeBreakdown = await Notification_1.default.aggregate([
            {
                $match: {
                    createdAt: { $lt: cutoffDate },
                    isRead: true,
                },
            },
            {
                $group: {
                    _id: '$type',
                    count: { $sum: 1 },
                },
            },
            { $sort: { count: -1 } },
        ]);
        console.log('📊 Breakdown by type:');
        typeBreakdown.forEach((t) => {
            console.log(`   ${t._id}: ${t.count}`);
        });
        console.log();
        // 3. Confirm deletion (5-second grace period)
        console.log('⚠️  WARNING: This will permanently delete these notifications!');
        console.log('   Press Ctrl+C to cancel, or wait 5 seconds to continue...\n');
        await new Promise((resolve) => setTimeout(resolve, 5000));
        // 4. Perform deletion
        console.log('🗑️  Deleting old notifications...');
        const result = await Notification_1.default.deleteMany({
            createdAt: { $lt: cutoffDate },
            isRead: true,
        });
        console.log(`✅ Deleted ${result.deletedCount} notifications\n`);
        // 5. Show remaining counts
        const remainingCount = await Notification_1.default.countDocuments();
        const unreadCount = await Notification_1.default.countDocuments({ isRead: false });
        console.log('📊 Remaining notifications:');
        console.log(`   Total:  ${remainingCount}`);
        console.log(`   Unread: ${unreadCount}`);
        console.log(`   Read:   ${remainingCount - unreadCount}\n`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('✅ Cleanup complete!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        await mongoose_1.default.disconnect();
        process.exit(0);
    }
    catch (error) {
        console.error('❌ Cleanup error:', error);
        process.exit(1);
    }
}
cleanupOldNotifications();
//# sourceMappingURL=cleanupOldNotification.js.map