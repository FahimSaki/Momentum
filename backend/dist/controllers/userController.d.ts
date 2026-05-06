import { Request, Response } from 'express';
export declare const getProfile: (req: Request, res: Response) => Promise<void>;
export declare const updateProfile: (req: Request, res: Response) => Promise<void>;
export declare const updateNotificationSettings: (req: Request, res: Response) => Promise<void>;
export declare const registerFcmToken: (req: Request, res: Response) => Promise<void>;
export declare const removeFcmToken: (req: Request, res: Response) => Promise<void>;
export declare const findByInviteId: (req: Request, res: Response) => Promise<void>;
export declare const searchUsers: (req: Request, res: Response) => Promise<void>;
export declare const changePassword: (req: Request, res: Response) => Promise<void>;
export declare const deleteAccount: (req: Request, res: Response) => Promise<void>;
//# sourceMappingURL=userController.d.ts.map