import { Router } from 'express';
import {
    createTeam,
    getUserTeams,
    getTeamDetails,
    inviteToTeam,
    respondToInvitation,
    getPendingInvitations,
    updateTeamSettings,
    removeTeamMember,
    leaveTeam,
    deleteTeam,
} from '../controllers/teamController';
import { authenticateToken } from '../middleware/middle_auth';

const router = Router();

router.use(authenticateToken);

router.post('/', createTeam);
router.get('/', getUserTeams);
router.get('/invitations/pending', getPendingInvitations);
router.get('/:teamId', getTeamDetails);
router.put('/:teamId/settings', updateTeamSettings);
router.delete('/:teamId', deleteTeam);
router.post('/:teamId/invite', inviteToTeam);
router.patch('/invitations/:invitationId/respond', respondToInvitation);
router.delete('/:teamId/members/:memberId', removeTeamMember);
router.post('/:teamId/leave', leaveTeam);

export default router;