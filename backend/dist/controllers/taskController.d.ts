import { Request, Response } from 'express';
export declare const createTask: (req: Request, res: Response) => Promise<void>;
export declare const updateTask: (req: Request, res: Response) => Promise<void>;
export declare const completeTask: (req: Request, res: Response) => Promise<void>;
export declare const deleteTask: (req: Request, res: Response) => Promise<void>;
export declare const getUserTasks: (req: Request, res: Response) => Promise<void>;
export declare const getTeamTasks: (req: Request, res: Response) => Promise<void>;
export declare const getTaskHistory: (req: Request, res: Response) => Promise<void>;
export declare const getDashboardStats: (req: Request, res: Response) => Promise<void>;
//# sourceMappingURL=taskController.d.ts.map