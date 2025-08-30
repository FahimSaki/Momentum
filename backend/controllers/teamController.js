import Team from '../models/Team.js';
import User from '../models/User.js';
import TeamInvitation from '../models/TeamInvitation.js';
import Notification from '../models/Notification.js';
import { sendNotification } from '../services/notification_Service.js';

// Create a new team
export const createTeam = async (req, res) => {
    try {
        const { name, description } = req.body;
        const userId = req.userId;

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ message: 'Team name is required' });
        }

        const team = new Team({
            name: name.trim(),
            description: description?.trim(),
            owner: userId,
            members: [{
                user: userId,
                role: 'owner'
            }]
        });

        await team.save();

        // Update user's teams array
        await User.findByIdAndUpdate(userId, {
            $push: { teams: team._id }
        });

        await team.populate('members.user', 'name email avatar');

        res.status(201).json({
            message: 'Team created successfully',
            team
        });
    } catch (err) {
        console.error('Create team error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get user's teams
export const getUserTeams = async (req, res) => {
    try {
        const userId = req.userId;

        const teams = await Team.find({
            'members.user': userId,
            isActive: true
        })
            .populate('owner', 'name email avatar')
            .populate('members.user', 'name email avatar')
            .sort({ createdAt: -1 });

        res.json(teams);
    } catch (err) {
        console.error('Get user teams error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get team details
export const getTeamDetails = async (req, res) => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId)
            .populate('owner', 'name email avatar')
            .populate('members.user', 'name email avatar')
            .populate('members.invitedBy', 'name email');

        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        // Check if user is a member
        const isMember = team.members.some(member =>
            member.user._id.toString() === userId
        );

        if (!isMember) {
            return res.status(403).json({ message: 'Access denied' });
        }

        res.json(team);
    } catch (err) {
        console.error('Get team details error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Invite user to team
export const inviteToTeam = async (req, res) => {
    try {
        const { teamId } = req.params;
        const { email, role = 'member', message } = req.body;
        const inviterId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        // Check if inviter has permission
        const inviterMember = team.members.find(m =>
            m.user.toString() === inviterId
        );

        if (!inviterMember) {
            return res.status(403).json({ message: 'You are not a team member' });
        }

        const canInvite = inviterMember.role === 'owner' ||
            inviterMember.role === 'admin' ||
            team.settings.allowMemberInvite;

        if (!canInvite) {
            return res.status(403).json({
                message: 'You do not have permission to invite members'
            });
        }

        // Find user by email
        const invitee = await User.findOne({ email: email.toLowerCase().trim() });

        if (!invitee) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Check if user is already a member
        const isAlreadyMember = team.members.some(m =>
            m.user.toString() === invitee._id.toString()
        );

        if (isAlreadyMember) {
            return res.status(400).json({ message: 'User is already a team member' });
        }

        // Check for existing pending invitation
        const existingInvitation = await TeamInvitation.findOne({
            team: teamId,
            invitee: invitee._id,
            status: 'pending'
        });

        if (existingInvitation) {
            return res.status(400).json({
                message: 'User already has a pending invitation to this team'
            });
        }

        // Create invitation
        const invitation = new TeamInvitation({
            team: teamId,
            inviter: inviterId,
            invitee: invitee._id,
            email: invitee.email,
            role,
            message
        });

        await invitation.save();

        // Create notification for invitee
        const notification = new Notification({
            recipient: invitee._id,
            sender: inviterId,
            team: teamId,
            type: 'team_invitation',
            title: 'Team Invitation',
            message: `You've been invited to join "${team.name}"`,
            data: {
                teamId,
                invitationId: invitation._id,
                teamName: team.name,
                inviterName: req.user.name
            }
        });

        await notification.save();

        // Send push notification
        await sendNotification(invitee._id, {
            title: 'Team Invitation',
            body: `${req.user.name} invited you to join "${team.name}"`,
            data: {
                type: 'team_invitation',
                teamId: teamId,
                invitationId: invitation._id.toString()
            }
        });

        res.json({
            message: 'Invitation sent successfully',
            invitation
        });
    } catch (err) {
        console.error('Invite to team error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Respond to team invitation
export const respondToInvitation = async (req, res) => {
    try {
        const { invitationId } = req.params;
        const { response } = req.body; // 'accepted' or 'declined'
        const userId = req.userId;

        const invitation = await TeamInvitation.findById(invitationId)
            .populate('team')
            .populate('inviter', 'name email');

        if (!invitation) {
            return res.status(404).json({ message: 'Invitation not found' });
        }

        if (invitation.invitee.toString() !== userId) {
            return res.status(403).json({ message: 'This invitation is not for you' });
        }

        if (invitation.status !== 'pending') {
            return res.status(400).json({
                message: `Invitation already ${invitation.status}`
            });
        }

        if (invitation.expiresAt < new Date()) {
            invitation.status = 'expired';
            await invitation.save();
            return res.status(400).json({ message: 'Invitation has expired' });
        }

        invitation.status = response;
        await invitation.save();

        if (response === 'accepted') {
            // Add user to team
            const team = await Team.findById(invitation.team._id);
            team.members.push({
                user: userId,
                role: invitation.role,
                invitedBy: invitation.inviter
            });
            await team.save();

            // Add team to user's teams array
            await User.findByIdAndUpdate(userId, {
                $push: { teams: team._id }
            });

            // Notify team members about new member
            const memberNotifications = team.members
                .filter(m => m.user.toString() !== userId)
                .map(member => ({
                    recipient: member.user,
                    sender: userId,
                    team: team._id,
                    type: 'team_member_joined',
                    title: 'New Team Member',
                    message: `${req.user.name} joined the team "${team.name}"`,
                    data: {
                        teamId: team._id,
                        newMemberName: req.user.name
                    }
                }));

            if (memberNotifications.length > 0) {
                await Notification.insertMany(memberNotifications);
            }
        }

        res.json({
            message: `Invitation ${response} successfully`,
            invitation
        });
    } catch (err) {
        console.error('Respond to invitation error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Get user's pending invitations
export const getPendingInvitations = async (req, res) => {
    try {
        const userId = req.userId;

        const invitations = await TeamInvitation.find({
            invitee: userId,
            status: 'pending',
            expiresAt: { $gt: new Date() }
        })
            .populate('team', 'name description')
            .populate('inviter', 'name email avatar')
            .sort({ createdAt: -1 });

        res.json(invitations);
    } catch (err) {
        console.error('Get pending invitations error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Update team settings
export const updateTeamSettings = async (req, res) => {
    try {
        const { teamId } = req.params;
        const { settings } = req.body;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        // Check if user is owner or admin
        const member = team.members.find(m => m.user.toString() === userId);
        if (!member || !['owner', 'admin'].includes(member.role)) {
            return res.status(403).json({
                message: 'Only team owners and admins can update settings'
            });
        }

        team.settings = { ...team.settings, ...settings };
        await team.save();

        res.json({
            message: 'Team settings updated successfully',
            team
        });
    } catch (err) {
        console.error('Update team settings error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Remove team member
export const removeTeamMember = async (req, res) => {
    try {
        const { teamId, memberId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        // Check permissions
        const currentMember = team.members.find(m =>
            m.user.toString() === userId
        );

        if (!currentMember) {
            return res.status(403).json({ message: 'You are not a team member' });
        }

        const targetMember = team.members.find(m =>
            m.user.toString() === memberId
        );

        if (!targetMember) {
            return res.status(404).json({ message: 'Member not found in team' });
        }

        // Owner cannot be removed
        if (targetMember.role === 'owner') {
            return res.status(400).json({ message: 'Cannot remove team owner' });
        }

        // Check if user has permission to remove this member
        const canRemove = currentMember.role === 'owner' ||
            (currentMember.role === 'admin' && targetMember.role !== 'admin') ||
            (currentMember.user.toString() === memberId); // Self-removal

        if (!canRemove) {
            return res.status(403).json({
                message: 'You do not have permission to remove this member'
            });
        }

        // Remove member from team
        team.members = team.members.filter(m =>
            m.user.toString() !== memberId
        );
        await team.save();

        // Remove team from user's teams array
        await User.findByIdAndUpdate(memberId, {
            $pull: { teams: teamId }
        });

        res.json({
            message: 'Member removed successfully'
        });
    } catch (err) {
        console.error('Remove team member error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Leave team (self-removal)
export const leaveTeam = async (req, res) => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        const member = team.members.find(m => m.user.toString() === userId);
        if (!member) {
            return res.status(400).json({ message: 'You are not a member of this team' });
        }

        if (member.role === 'owner') {
            return res.status(400).json({
                message: 'Team owner cannot leave. Transfer ownership first or delete the team.'
            });
        }

        // Remove user from team
        team.members = team.members.filter(m => m.user.toString() !== userId);
        await team.save();

        // Remove team from user's teams array
        await User.findByIdAndUpdate(userId, {
            $pull: { teams: teamId }
        });

        res.json({
            message: 'Left team successfully'
        });
    } catch (err) {
        console.error('Leave team error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};

// Delete team (owner only)
export const deleteTeam = async (req, res) => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) {
            return res.status(404).json({ message: 'Team not found' });
        }

        if (team.owner.toString() !== userId) {
            return res.status(403).json({
                message: 'Only team owner can delete the team'
            });
        }

        // Remove team from all members' teams arrays
        await User.updateMany(
            { teams: teamId },
            { $pull: { teams: teamId } }
        );

        // Mark team as inactive instead of deleting (for data integrity)
        team.isActive = false;
        await team.save();

        res.json({
            message: 'Team deleted successfully'
        });
    } catch (err) {
        console.error('Delete team error:', err);
        res.status(500).json({ message: 'Server error', error: err.message });
    }
};