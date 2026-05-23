import Team from '../models/Team';
import Task from '../models/Task';
import TaskHistory from '../models/TaskHistory';

export async function getTaskTeam(taskId: string) {
    return Team.findOne({
        'tasks.task': taskId,
    });
}

export async function canCreateTask(
    userId: string,
    teamId: string,
) {
    const team = await Team.findById(teamId);

    if (!team) {
        return false;
    }

    const member = team.members.find(
        (m: any) => m.user.toString() === userId,
    );

    if (!member) {
        return false;
    }

    return ['owner', 'admin'].includes(member.role);
}

export async function canEditTask(
    userId: string,
    taskId: string,
) {
    const team = await getTaskTeam(taskId);

    if (!team) {
        return false;
    }

    const member = team.members.find(
        (m: any) => m.user.toString() === userId,
    );

    if (!member) {
        return false;
    }

    return ['owner', 'admin'].includes(member.role);
}

export async function canDeleteTask(
    userId: string,
    taskId: string,
) {
    return canEditTask(userId, taskId);
}

export async function saveTaskToHistory(task: any) {
    try {
        const completedDates = task.completedDates || [];

        if (completedDates.length === 0) {
            return;
        }

        const historyEntries = completedDates.map(
            (date: Date) => ({
                userId: task.userId,
                taskName: task.name,
                completedAt: date,
                originalTaskId: task._id,
            }),
        );

        await TaskHistory.insertMany(historyEntries);
    } catch (error) {
        console.error(
            'Error saving task history:',
            error,
        );
    }
}