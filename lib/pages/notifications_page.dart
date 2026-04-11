import 'package:flutter/material.dart';
import 'package:momentum/components/notification_tile.dart';
import 'package:momentum/database/task_database.dart';
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

    setState(() => _isLoading = true);

    try {
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.refreshData();
      _logger.i('Notifications data refreshed');
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
    if (db.pendingInvitations.isEmpty) {
      return const Center(child: Text('No pending invitations'));
    }

    return ListView.builder(
      itemCount: db.pendingInvitations.length,
      itemBuilder: (context, index) {
        final invitation = db.pendingInvitations[index];

        return ListTile(
          title: Text(invitation.team.name),
          subtitle: Text(invitation.inviter.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => db.respondToInvitation(invitation.id, false),
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () => db.respondToInvitation(invitation.id, true),
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(TaskDatabase db) {
    if (db.notifications.isEmpty) {
      return const Center(child: Text('No notifications yet'));
    }

    return ListView.builder(
      itemCount: db.notifications.length,
      itemBuilder: (context, index) {
        final notification = db.notifications[index];

        return NotificationTile(
          notification: notification,
          onTap: () => _handleNotificationTap(notification, db),
        );
      },
    );
  }

  void _handleNotificationTap(dynamic notification, TaskDatabase db) {
    if (!notification.isRead) {
      db.markNotificationAsRead(notification.id);
    }

    Navigator.pop(context);
  }
}
