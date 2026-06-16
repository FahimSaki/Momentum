import 'package:flutter/material.dart';
import 'package:momentum/components/notification_tile.dart';
import 'package:momentum/components/responsive_layout.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<TaskDatabase>(context, listen: false).refreshData();
    } catch (e, st) {
      _logger.e('Error refreshing notifications', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  onSelected: (v) async {
                    if (v == 'mark_all_read') {
                      await db.markAllNotificationsAsRead();
                    } else {
                      await _refresh();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read),
                          SizedBox(width: 8),
                          Text('Mark all read'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
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
                onPressed: _refresh,
              );
            },
          ),
        ],
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) => TabBarView(
          controller: _tabController,
          children: [
            _InvitationsTab(db: db, isLoading: _isLoading, onRefresh: _refresh),
            _ActivityTab(
              db: db,
              isLoading: _isLoading,
              onRefresh: _refresh,
              onTap: (n) {
                if (!n.isRead) db.markNotificationAsRead(n.id);
                switch (n.type) {
                  case 'team_invitation':
                    _tabController.animateTo(0);
                    break;
                  default:
                    Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invitations tab ───────────────────────────────────────────────────────────

class _InvitationsTab extends StatelessWidget {
  final TaskDatabase db;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _InvitationsTab({
    required this.db,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

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

    // ── Centre + cap width of the list ────────────────────────────────────
    return ResponsiveBody(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: db.pendingInvitations.length,
          itemBuilder: (context, i) {
            final inv = db.pendingInvitations[i];
            return _InvitationCard(
              invitation: inv,
              onAccept: () => _respond(context, inv, true),
              onDecline: () => _respond(context, inv, false),
            );
          },
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    TeamInvitation inv,
    bool accept,
  ) async {
    try {
      await db.respondToInvitation(inv.id, accept);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Invitation accepted! Welcome to ${inv.team.name}! 🎉'
                  : 'Invitation declined',
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        await onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// ── Activity tab ──────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final TaskDatabase db;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(dynamic) onTap;

  const _ActivityTab({
    required this.db,
    required this.isLoading,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

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

    // ── Centre + cap width of the list ────────────────────────────────────
    return ResponsiveBody(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          itemCount: db.notifications.length,
          itemBuilder: (_, i) => NotificationTile(
            notification: db.notifications[i],
            onTap: () => onTap(db.notifications[i]),
          ),
        ),
      ),
    );
  }
}

// ── Invitation card ───────────────────────────────────────────────────────────

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
  bool _processing = false;

  Future<void> _press(VoidCallback action) async {
    setState(() => _processing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      action();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
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
                        inv.team.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (inv.team.description?.isNotEmpty == true)
                        Text(
                          inv.team.description!,
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
                        'Invited by ${inv.inviter.name}',
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
                          inv.role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (inv.message?.isNotEmpty == true) ...[
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
                            inv.message!,
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
                    onPressed: _processing
                        ? null
                        : () => _press(widget.onDecline),
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
                    onPressed: _processing
                        ? null
                        : () => _press(widget.onAccept),
                    icon: _processing
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
