import express from 'express';
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
    deleteTeam
} from '../controllers/teamController.js';

const router = express.Router();

// Team management
router.post('/', createTeam);
router.get('/', getUserTeams);
router.get('/:teamId', getTeamDetails);
router.put('/:teamId/settings', updateTeamSettings);
router.delete('/:teamId', deleteTeam);

// Team membership
router.post('/:teamId/invite', inviteToTeam);
router.delete('/:teamId/members/:memberId', removeTeamMember);
router.post('/:teamId/leave', leaveTeam);

// Invitations
router.get('/invitations/pending', getPendingInvitations);
router.put('/invitations/:invitationId/respond', respondToInvitation);

export default router;