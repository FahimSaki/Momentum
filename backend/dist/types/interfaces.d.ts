import { Request } from 'express';
import { Types, HydratedDocument } from 'mongoose';
declare global {
    namespace Express {
        interface Request {
            userId: string;
            user: IUserDocument;
        }
    }
}
export interface IProfileVisibility {
    showEmail: boolean;
    showName: boolean;
    showBio: boolean;
}
export interface IUserNotificationSettings {
    email: boolean;
    push: boolean;
    inApp: boolean;
    taskAssigned: boolean;
    taskCompleted: boolean;
    teamInvitations: boolean;
    dailyReminder: boolean;
}
export interface IFcmToken {
    token: string;
    platform: 'android' | 'ios' | 'web' | 'legacy';
    lastUsed: Date;
}
export interface IUser {
    email: string;
    password?: string;
    googleId?: string;
    name: string;
    avatar?: string;
    bio?: string;
    timezone: string;
    teams: Types.ObjectId[];
    notificationSettings: IUserNotificationSettings;
    fcmTokens: IFcmToken[];
    fcmToken?: string;
    tasksAssigned: Types.ObjectId[];
    isActive: boolean;
    lastLoginAt: Date;
    inviteId: string;
    isPublic: boolean;
    profileVisibility: IProfileVisibility;
    createdAt: Date;
    updatedAt: Date;
}
export type IUserDocument = HydratedDocument<IUser>;
export interface ICompletedBy {
    user: Types.ObjectId;
    completedAt: Date;
}
export interface IRecurrence {
    isRecurring: boolean;
    pattern?: 'daily' | 'weekly' | 'monthly';
    interval: number;
}
export interface ITask {
    name: string;
    description?: string;
    assignedTo: Types.ObjectId[];
    assignedBy?: Types.ObjectId;
    team?: Types.ObjectId;
    priority: 'low' | 'medium' | 'high' | 'urgent';
    dueDate?: Date;
    tags: string[];
    completedDays: Date[];
    completedBy: ICompletedBy[];
    lastCompletedDate?: Date;
    isArchived: boolean;
    archivedAt?: Date;
    isTeamTask: boolean;
    assignmentType: 'individual' | 'multiple' | 'team';
    recurrence: IRecurrence;
    createdAt: Date;
    updatedAt: Date;
}
export type ITaskDocument = HydratedDocument<ITask>;
export interface ITeamNotificationSettings {
    taskAssigned: boolean;
    taskCompleted: boolean;
    memberJoined: boolean;
}
export interface ITeamSettings {
    allowMemberInvite: boolean;
    taskAutoDelete: boolean;
    notificationSettings: ITeamNotificationSettings;
}
export interface ITeamMember {
    user: Types.ObjectId;
    role: 'owner' | 'admin' | 'member';
    joinedAt: Date;
    invitedBy?: Types.ObjectId;
}
export interface ITeam {
    name: string;
    description?: string;
    owner: Types.ObjectId;
    members: ITeamMember[];
    settings: ITeamSettings;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
}
export type ITeamDocument = HydratedDocument<ITeam>;
export interface ITeamInvitation {
    team: Types.ObjectId;
    inviter: Types.ObjectId;
    invitee: Types.ObjectId;
    email: string;
    role: 'admin' | 'member';
    status: 'pending' | 'accepted' | 'declined' | 'expired';
    expiresAt: Date;
    message?: string;
    createdAt: Date;
    updatedAt: Date;
}
export type ITeamInvitationDocument = HydratedDocument<ITeamInvitation>;
export interface ITaskHistory {
    userId: Types.ObjectId;
    taskName: string;
    completedDays: Date[];
    teamId?: Types.ObjectId;
    createdAt: Date;
    updatedAt: Date;
}
export type ITaskHistoryDocument = HydratedDocument<ITaskHistory>;
export type NotificationType = 'task_assigned' | 'task_completed' | 'team_invitation' | 'team_member_joined' | 'task_due_reminder';
export interface INotification {
    recipient: Types.ObjectId;
    sender?: Types.ObjectId;
    team?: Types.ObjectId;
    task?: Types.ObjectId;
    type: NotificationType;
    title: string;
    message: string;
    data?: Record<string, unknown>;
    isRead: boolean;
    readAt?: Date;
    isSent: boolean;
    fcmMessageId?: string;
    createdAt: Date;
    updatedAt: Date;
}
export type INotificationDocument = HydratedDocument<INotification>;
export interface NotificationPayload {
    type?: string;
    title: string;
    body: string;
    senderId?: Types.ObjectId | string;
    taskId?: Types.ObjectId | string;
    teamId?: Types.ObjectId | string;
    notificationId?: string;
    data?: Record<string, string>;
}
export interface AuthenticatedRequest extends Request {
    userId: string;
    user: IUserDocument;
}
export interface JwtPayload {
    userId: string;
}
//# sourceMappingURL=interfaces.d.ts.map