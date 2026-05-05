import { Request, Response } from 'express';
import Team from '../models/Team';
import User from '../models/User';
import TeamInvitation from '../models/TeamInvitation';
import Notification from '../models/Notification';
import { sendNotification } from '../services/notificationService';
import { Types } from 'mongoose';

// ── Create team ───────────────────────────────────────────────────────────

export const createTeam = async (req: Request, res: Response): Promise<void> => {
    try {
        const { name, description } = req.body as { name?: string; description?: string };
        const userId = req.userId;

        if (!name?.trim()) { res.status(400).json({ message: 'Team name is required' }); return; }
        if (name.trim().length > 100) { res.status(400).json({ message: 'Team name must be under 100 characters' }); return; }

        const user = await User.findById(userId);
        if (!user) { res.status(404).json({ message: 'User not found' }); return; }

        const team = new Team({
            name: name.trim(),
            description: description?.trim() || null,
            owner: userId,
            members: [{ user: userId, role: 'owner', joinedAt: new Date() }],
            settings: {
                allowMemberInvite: false,
                taskAutoDelete: true,
                notificationSettings: { taskAssigned: true, taskCompleted: true, memberJoined: true },
            },
            isActive: true,
        });

        await team.save();
        await User.findByIdAndUpdate(userId, { $addToSet: { teams: team._id } });
        await team.populate([
            { path: 'owner', select: 'name email avatar' },
            { path: 'members.user', select: 'name email avatar' },
        ]);

        res.status(201).json({ message: 'Team created successfully', team });
    } catch (err: any) {
        console.error('Create team error:', err);
        if (err.code === 11000) { res.status(400).json({ message: 'A team with this name already exists' }); return; }
        if (err.name === 'ValidationError') {
            const errors = Object.values(err.errors).map((e: any) => e.message);
            res.status(400).json({ message: 'Validation error', errors });
            return;
        }
        res.status(500).json({ message: 'Server error during team creation' });
    }
};

// ── Get user teams ────────────────────────────────────────────────────────

export const getUserTeams = async (req: Request, res: Response): Promise<void> => {
    try {
        const userId = req.userId;
        const teams = await Team.find({ 'members.user': userId, isActive: true })
            .populate('owner', 'name email avatar')
            .populate('members.user', 'name email avatar')
            .sort({ createdAt: -1 });
        res.json(teams);
    } catch (err) {
        console.error('Get user teams error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get team details ──────────────────────────────────────────────────────

export const getTeamDetails = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId)
            .populate('owner', 'name email avatar')
            .populate('members.user', 'name email avatar')
            .populate('members.invitedBy', 'name email');

        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const isMember = team.members.some((m: any) => m.user._id.toString() === userId);
        if (!isMember) { res.status(403).json({ message: 'Access denied' }); return; }

        res.json(team);
    } catch (err) {
        console.error('Get team details error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Invite to team ────────────────────────────────────────────────────────

export const inviteToTeam = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const { email, inviteId, role = 'member', message } = req.body;
        const inviterId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const inviterMember = team.members.find((m) => m.user.toString() === inviterId);
        if (!inviterMember) { res.status(403).json({ message: 'You are not a team member' }); return; }

        const canInvite =
            inviterMember.role === 'owner' ||
            inviterMember.role === 'admin' ||
            team.settings.allowMemberInvite;
        if (!canInvite) { res.status(403).json({ message: 'You do not have permission to invite members' }); return; }

        let invitee: any = null;
        if (inviteId) {
            invitee = await User.findOne({ inviteId, isPublic: true });
            if (!invitee) { res.status(404).json({ message: 'User not found with that invite ID' }); return; }
        } else if (email) {
            invitee = await User.findOne({ email: email.toLowerCase().trim() });
            if (!invitee) { res.status(404).json({ message: 'User not found with that email' }); return; }
        } else {
            res.status(400).json({ message: 'Either email or invite ID is required' }); return;
        }

        const isAlreadyMember = team.members.some((m) => m.user.toString() === invitee._id.toString());
        if (isAlreadyMember) { res.status(400).json({ message: 'User is already a team member' }); return; }

        const existing = await TeamInvitation.findOne({ team: teamId, invitee: invitee._id });
        if (existing) {
            if (existing.status === 'pending') {
                res.status(400).json({ message: 'User already has a pending invitation to this team' }); return;
            }
            if (existing.status === 'accepted') {
                res.status(400).json({ message: 'This invitation was already accepted' }); return;
            }
            await TeamInvitation.deleteOne({ _id: existing._id });
        }

        const invitation = new TeamInvitation({
            team: teamId,
            inviter: inviterId,
            invitee: invitee._id,
            email: invitee.email,
            role,
            message,
            expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        });
        await invitation.save();

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
                inviterName: req.user.name,
            },
        });
        await notification.save();

        try {
            await sendNotification(invitee._id.toString(), {
                title: 'Team Invitation',
                body: `${req.user.name} invited you to join "${team.name}"`,
                data: { type: 'team_invitation', teamId: teamId.toString(), invitationId: invitation._id.toString() },
            });
        } catch (e) { console.error('FCM error (non-critical):', e); }

        res.json({ message: 'Invitation sent successfully', invitation });
    } catch (err) {
        console.error('Invite to team error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Respond to invitation ─────────────────────────────────────────────────

export const respondToInvitation = async (req: Request, res: Response): Promise<void> => {
    try {
        const { invitationId } = req.params;
        const { response } = req.body as { response: 'accepted' | 'declined' };
        const userId = req.userId;

        const invitation = await TeamInvitation.findById(invitationId)
            .populate('team')
            .populate('inviter', 'name email');
        if (!invitation) { res.status(404).json({ message: 'Invitation not found' }); return; }
        if (invitation.invitee.toString() !== userId) { res.status(403).json({ message: 'This invitation is not for you' }); return; }
        if (invitation.status !== 'pending') { res.status(400).json({ message: `Invitation already ${invitation.status}` }); return; }
        if (invitation.expiresAt < new Date()) {
            invitation.status = 'expired';
            await invitation.save();
            res.status(400).json({ message: 'Invitation has expired' }); return;
        }

        invitation.status = response;
        await invitation.save();

        if (response === 'accepted') {
            const team = await Team.findById((invitation.team as any)._id);
            if (team) {
                team.members.push({ user: new Types.ObjectId(userId), role: invitation.role, joinedAt: new Date(), invitedBy: invitation.inviter as any });
                await team.save();
                await User.findByIdAndUpdate(userId, { $push: { teams: team._id } });

                const memberNotifs = team.members
                    .filter((m) => m.user.toString() !== userId)
                    .map((m) => ({
                        recipient: m.user,
                        sender: new Types.ObjectId(userId),
                        team: team._id,
                        type: 'team_member_joined' as const,
                        title: 'New Team Member',
                        message: `${req.user.name} joined the team "${team.name}"`,
                        data: { teamId: team._id, newMemberName: req.user.name },
                    }));
                if (memberNotifs.length) await Notification.insertMany(memberNotifs);
            }
        }

        res.json({ message: `Invitation ${response} successfully`, invitation });
    } catch (err) {
        console.error('Respond to invitation error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get pending invitations ───────────────────────────────────────────────

export const getPendingInvitations = async (req: Request, res: Response): Promise<void> => {
    try {
        const userId = req.userId;
        const invitations = await TeamInvitation.find({
            invitee: userId,
            status: 'pending',
            expiresAt: { $gt: new Date() },
        })
            .populate('team', 'name description')
            .populate('inviter', 'name email avatar')
            .sort({ createdAt: -1 })
            .lean();

        const cleaned = invitations.map((inv: any) => ({
            _id: inv._id,
            status: inv.status,
            role: inv.role || 'member',
            message: inv.message || '',
            expiresAt: inv.expiresAt,
            createdAt: inv.createdAt,
            team: inv.team
                ? { _id: inv.team._id, name: inv.team.name || 'Unknown Team', description: inv.team.description || '' }
                : { _id: 'unknown', name: 'Unknown Team', description: '' },
            inviter: inv.inviter
                ? { _id: inv.inviter._id, name: inv.inviter.name || 'Unknown', email: inv.inviter.email || '', avatar: inv.inviter.avatar || null }
                : { _id: 'unknown', name: 'Unknown', email: '', avatar: null },
            invitee: inv.invitee,
        }));

        res.json(cleaned);
    } catch (err) {
        console.error('Get pending invitations error:', err);
        res.json([]);
    }
};

// ── Update team settings ──────────────────────────────────────────────────

export const updateTeamSettings = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const { settings } = req.body;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const member = team.members.find((m) => m.user.toString() === userId);
        if (!member || !['owner', 'admin'].includes(member.role)) {
            res.status(403).json({ message: 'Only owners and admins can update settings' }); return;
        }

        Object.assign(team.settings, settings);
        await team.save();
        res.json({ message: 'Team settings updated', team });
    } catch (err) {
        console.error('Update team settings error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Remove team member ────────────────────────────────────────────────────

export const removeTeamMember = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId, memberId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const currentMember = team.members.find((m) => m.user.toString() === userId);
        if (!currentMember) { res.status(403).json({ message: 'You are not a team member' }); return; }

        const targetMember = team.members.find((m) => m.user.toString() === memberId);
        if (!targetMember) { res.status(404).json({ message: 'Member not found in team' }); return; }
        if (targetMember.role === 'owner') { res.status(400).json({ message: 'Cannot remove team owner' }); return; }

        const canRemove =
            currentMember.role === 'owner' ||
            (currentMember.role === 'admin' && targetMember.role !== 'admin') ||
            currentMember.user.toString() === memberId;
        if (!canRemove) { res.status(403).json({ message: 'You do not have permission to remove this member' }); return; }

        team.members = team.members.filter((m) => m.user.toString() !== memberId);
        await team.save();
        await User.findByIdAndUpdate(memberId, { $pull: { teams: teamId } });

        res.json({ message: 'Member removed successfully' });
    } catch (err) {
        console.error('Remove team member error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Leave team ────────────────────────────────────────────────────────────

export const leaveTeam = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }

        const member = team.members.find((m) => m.user.toString() === userId);
        if (!member) { res.status(400).json({ message: 'You are not a member of this team' }); return; }
        if (member.role === 'owner') { res.status(400).json({ message: 'Team owner cannot leave. Transfer ownership first.' }); return; }

        team.members = team.members.filter((m) => m.user.toString() !== userId);
        await team.save();
        await User.findByIdAndUpdate(userId, { $pull: { teams: teamId } });

        res.json({ message: 'Left team successfully' });
    } catch (err) {
        console.error('Leave team error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Delete team ───────────────────────────────────────────────────────────

export const deleteTeam = async (req: Request, res: Response): Promise<void> => {
    try {
        const { teamId } = req.params;
        const userId = req.userId;

        const team = await Team.findById(teamId);
        if (!team) { res.status(404).json({ message: 'Team not found' }); return; }
        if (team.owner.toString() !== userId) { res.status(403).json({ message: 'Only team owner can delete the team' }); return; }

        await User.updateMany({ teams: teamId }, { $pull: { teams: teamId } });
        team.isActive = false;
        await team.save();

        res.json({ message: 'Team deleted successfully' });
    } catch (err) {
        console.error('Delete team error:', err);
        res.status(500).json({ message: 'Server error' });
    }
};