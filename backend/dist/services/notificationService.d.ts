import { ITaskDocument, IUserDocument, NotificationPayload } from '../types/interfaces';
import { Types } from 'mongoose';
export declare const initFirebase: () => void;
export declare const sendNotification: (userId: string, payload: NotificationPayload) => Promise<boolean>;
export declare const updateFCMToken: (userId: string, token: string, platform?: string) => Promise<void>;
export declare const sendTaskAssignedNotification: (task: ITaskDocument, assigner: IUserDocument, recipientIds: string[]) => Promise<void>;
export declare const sendTaskCompletedNotification: (task: ITaskDocument, completer: IUserDocument, recipientId: Types.ObjectId | string) => Promise<void>;
export declare const sendDueDateReminders: () => Promise<number>;
export declare const cleanupOldNotifications: (daysOld?: number) => Promise<number>;
export declare const getUserNotifications: (userId: string, limit?: number, offset?: number, unreadOnly?: boolean) => Promise<{
    notifications: (import("mongoose").FlattenMaps<import("mongoose").Document<unknown, {}, import("../types/interfaces").INotification, {}, {}> & import("../types/interfaces").INotification & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }> & Required<{
        _id: Types.ObjectId;
    }>)[];
    totalCount: number;
    unreadCount: number;
}>;
export declare const markNotificationAsRead: (notificationId: string, userId: string) => Promise<(import("mongoose").Document<unknown, {}, import("mongoose").Document<unknown, {}, import("../types/interfaces").INotification, {}, {}> & import("../types/interfaces").INotification & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, {}, {}> & import("mongoose").Document<unknown, {}, import("../types/interfaces").INotification, {}, {}> & import("../types/interfaces").INotification & {
    _id: Types.ObjectId;
} & {
    __v: number;
} & Required<{
    _id: Types.ObjectId;
}>) | null>;
export declare const markAllNotificationsAsRead: (userId: string) => Promise<import("mongoose").UpdateWriteOpResult>;
//# sourceMappingURL=notificationService.d.ts.map