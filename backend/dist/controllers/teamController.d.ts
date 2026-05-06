import { Request, Response } from 'express';
export declare const createTeam: (req: Request, res: Response) => Promise<void>;
export declare const getUserTeams: (req: Request, res: Response) => Promise<void>;
export declare const getTeamDetails: (req: Request, res: Response) => Promise<void>;
export declare const inviteToTeam: (req: Request, res: Response) => Promise<void>;
export declare const respondToInvitation: (req: Request, res: Response) => Promise<void>;
export declare const getPendingInvitations: (req: Request, res: Response) => Promise<void>;
export declare const updateTeamSettings: (req: Request, res: Response) => Promise<void>;
export declare const removeTeamMember: (req: Request, res: Response) => Promise<void>;
export declare const leaveTeam: (req: Request, res: Response) => Promise<void>;
export declare const deleteTeam: (req: Request, res: Response) => Promise<void>;
//# sourceMappingURL=teamController.d.ts.map