"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const teamController_1 = require("../controllers/teamController");
const middle_auth_1 = require("../middleware/middle_auth");
const router = (0, express_1.Router)();
router.use(middle_auth_1.authenticateToken);
router.post('/', teamController_1.createTeam);
router.get('/', teamController_1.getUserTeams);
router.get('/invitations/pending', teamController_1.getPendingInvitations);
router.get('/:teamId', teamController_1.getTeamDetails);
router.put('/:teamId/settings', teamController_1.updateTeamSettings);
router.delete('/:teamId', teamController_1.deleteTeam);
router.post('/:teamId/invite', teamController_1.inviteToTeam);
router.patch('/invitations/:invitationId/respond', teamController_1.respondToInvitation);
router.delete('/:teamId/members/:memberId', teamController_1.removeTeamMember);
router.post('/:teamId/leave', teamController_1.leaveTeam);
exports.default = router;
//# sourceMappingURL=teams.js.map