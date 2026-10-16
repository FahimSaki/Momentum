"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTaskTeam = exports.saveTaskToHistory = exports.canDeleteTask = exports.canEditTask = exports.canCreateTask = void 0;
const Team_1 = __importDefault(require("../models/Team"));
const TaskHistory_1 = __importDefault(require("../models/TaskHistory"));
// Permission helpers 
/** Returns true if the user can create tasks in the team.
 *  Pass null for personal tasks — always allowed. */
const canCreateTask = (team, userId) => {
    if (!team)
        return true;
    const member = team.members.find((m) => m.user.toString() === userId);
    return !!member && ['owner', 'admin'].includes(member.role);
};
exports.canCreateTask = canCreateTask;
/** Returns true if the user can edit the task. */
const canEditTask = (task, team, userId) => {
    if (team) {
        const member = team.members.find((m) => m.user.toString() === userId);
        if (member && ['owner', 'admin'].includes(member.role))
            return true;
    }
    return task.assignedBy?.toString() === userId;
};
exports.canEditTask = canEditTask;
/** Returns true if the user can delete the task. Same rules as edit. */
const canDeleteTask = (task, team, userId) => (0, exports.canEditTask)(task, team, userId);
exports.canDeleteTask = canDeleteTask;
// History 
/** Saves a task's completedDays to TaskHistory before deletion.
 *  Merges with any existing record for the same user+taskName. */
const saveTaskToHistory = async (task) => {
    if (!task.completedDays?.length)
        return;
    for (const assigneeId of task.assignedTo ?? []) {
        try {
            const existing = await TaskHistory_1.default.findOne({
                userId: assigneeId,
                taskName: task.name,
            });
            if (existing) {
                const merged = [...existing.completedDays, ...task.completedDays];
                existing.completedDays = [
                    ...new Set(merged.map((d) => d.toISOString())),
                ].map((d) => new Date(d));
                await existing.save();
            }
            else {
                await TaskHistory_1.default.create({
                    userId: assigneeId,
                    completedDays: task.completedDays,
                    taskName: task.name,
                    teamId: task.team,
                });
            }
        }
        catch (err) {
            console.error(`Error saving task "${task.name}" to history for ${assigneeId}:`, err);
        }
    }
};
exports.saveTaskToHistory = saveTaskToHistory;
// Team lookup 
/** Fetches the Team document for a task, or null for personal tasks. */
const getTaskTeam = async (task) => {
    if (!task.team)
        return null;
    return Team_1.default.findById(task.team);
};
exports.getTaskTeam = getTaskTeam;
