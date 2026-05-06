export interface CleanupResult {
    archivedTasks: number;
    deletedAndPreservedTasks: number;
    cleanedTasks: number;
    processedDate: string;
    timestamp: string;
    status: 'success' | 'failed';
    error?: string;
}
export declare const runDailyCleanup: () => Promise<CleanupResult>;
export declare const runManualCleanup: () => Promise<CleanupResult>;
//# sourceMappingURL=cleanupScheduler.d.ts.map