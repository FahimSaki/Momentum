import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/team_invitation.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.refreshData();
      _logger.i('Notifications data refreshed');
    } catch (e, stackTrace) {
      _logger.e(
        'Error refreshing notifications data',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Invitations'),
            Tab(text: 'Activity'),
          ],
        ),
        actions: [
          Consumer<TaskDatabase>(
            builder: (context, db, _) {
              final hasUnread =
                  db.unreadNotificationCount > 0 ||
                  db.pendingInvitations.isNotEmpty;

              if (hasUnread) {
                return PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'mark_all_read':
                        await db.markAllNotificationsAsRead();
                        break;
                      case 'refresh':
                        await _refreshData();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read),
                          SizedBox(width: 8),
                          Text('Mark all read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              );
            },
          ),
        ],
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          return TabBarView(
            controller: _tabController,
            children: [_buildInvitationsTab(db), _buildActivityTab(db)],
          );
        },
      ),
    );
  }

  Widget _buildInvitationsTab(TaskDatabase db) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (db.pendingInvitations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No pending invitations',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Team invitations will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: db.pendingInvitations.length,
        itemBuilder: (context, index) {
          final invitation = db.pendingInvitations[index];
          return _InvitationCard(
            invitation: invitation,
            onAccept: () => _handleInvitation(db, invitation, true),
            onDecline: () => _handleInvitation(db, invitation, false),
          );
        },
      ),
    );
  }

  Widget _buildActivityTab(TaskDatabase db) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (db.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Activity notifications will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: db.notifications.length,
        itemBuilder: (context, index) {
          final notification = db.notifications[index];
          return _NotificationTile(
            notification: notification,
            onTap: () => _handleNotificationTap(notification, db),
          );
        },
      ),
    );
  }

  Future<void> _handleInvitation(
    TaskDatabase db,
    TeamInvitation invitation,
    bool accept,
  ) async {
    try {
      _logger.i(
        '${accept ? 'Accepting' : 'Declining'} invitation: ${invitation.id}',
      );

      await db.respondToInvitation(invitation.id, accept);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Invitation accepted! Welcome to ${invitation.team.name}! 🎉'
                  : 'Invitation declined',
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh data after handling invitation
        await _refreshData();
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling invitation', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleNotificationTap(dynamic notification, TaskDatabase db) {
    // Mark as read if not already
    if (!notification.isRead) {
      db.markNotificationAsRead(notification.id);
    }

    // Handle navigation based on notification type
    switch (notification.type) {
      case 'task_assigned':
      case 'task_completed':
        // Navigate back to home and switch to tasks tab
        Navigator.pop(context);
        break;
      case 'team_invitation':
        // Switch to invitations tab
        _tabController.animateTo(0);
        break;
      case 'team_member_joined':
        // Navigate back to home
        Navigator.pop(context);
        break;
    }
  }
}

class _InvitationCard extends StatefulWidget {
  final TeamInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.invitation.team.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.invitation.team.description != null &&
                          widget.invitation.team.description!.isNotEmpty)
                        Text(
                          widget.invitation.team.description!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Invited by ${widget.invitation.inviter.name}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.invitation.role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (widget.invitation.message != null &&
                      widget.invitation.message!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.message, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.invitation.message!,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() {
                              _isProcessing = true;
                            });
                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );
                              widget.onDecline();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isProcessing = false;
                                });
                              }
                            }
                          },
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() {
                              _isProcessing = true;
                            });
                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );
                              widget.onAccept();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isProcessing = false;
                                });
                              }
                            }
                          },
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: notification.isRead
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: ListTile(
        leading: _getNotificationIcon(),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  notification.timeAgo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (notification.sender != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.person, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    notification.sender!.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: onTap,
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  Widget _getNotificationIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'task_assigned':
        iconData = Icons.assignment;
        iconColor = Colors.blue;
        break;
      case 'task_completed':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'team_invitation':
        iconData = Icons.group_add;
        iconColor = Colors.orange;
        break;
      case 'team_member_joined':
        iconData = Icons.group;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}
