import Team from '../models/Team';
import TaskHistory from '../models/TaskHistory';
import { ITaskDocument, ITeamDocument } from '../types/interfaces';

// ── Permission helpers ────────────────────────────────────────────────────

/** Returns true if the user can create tasks in the team.
 *  Pass null for personal tasks — always allowed. */
export const canCreateTask = (
    team: ITeamDocument | null,
    userId: string
): boolean => {
    if (!team) return true;
    const member = team.members.find((m) => m.user.toString() === userId);
    return !!member && ['owner', 'admin'].includes(member.role);
};

/** Returns true if the user can edit the task. */
export const canEditTask = (
    task: ITaskDocument,
    team: ITeamDocument | null,
    userId: string
): boolean => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role)) return true;
    }
    return task.assignedBy?.toString() === userId;
};

/** Returns true if the user can delete the task. Same rules as edit. */
export const canDeleteTask = (
    task: ITaskDocument,
    team: ITeamDocument | null,
    userId: string
): boolean => canEditTask(task, team, userId);

// ── History ───────────────────────────────────────────────────────────────

/** Saves a task's completedDays to TaskHistory before deletion.
 *  Merges with any existing record for the same user+taskName. */
export const saveTaskToHistory = async (task: ITaskDocument): Promise<void> => {
    if (!task.completedDays?.length) return;

    for (const assigneeId of task.assignedTo ?? []) {
        try {
            const existing = await TaskHistory.findOne({
                userId: assigneeId,
                taskName: task.name,
            });

            if (existing) {
                const merged = [...existing.completedDays, ...task.completedDays];
                existing.completedDays = [
                    ...new Set(merged.map((d) => d.toISOString())),
                ].map((d) => new Date(d));
                await existing.save();
            } else {
                await TaskHistory.create({
                    userId: assigneeId,
                    completedDays: task.completedDays,
                    taskName: task.name,
                    teamId: task.team,
                });
            }
        } catch (err) {
            console.error(
                `Error saving task "${task.name}" to history for ${assigneeId}:`,
                err
            );
        }
    }
};

// ── Team lookup ───────────────────────────────────────────────────────────

/** Fetches the Team document for a task, or null for personal tasks. */
export const getTaskTeam = async (
    task: ITaskDocument
): Promise<ITeamDocument | null> => {
    if (!task.team) return null;
    return Team.findById(task.team);
};