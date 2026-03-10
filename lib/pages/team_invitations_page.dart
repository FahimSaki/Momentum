import 'package:flutter/material.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:provider/provider.dart';

class TeamInvitationsPage extends StatelessWidget {
  const TeamInvitationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<TaskDatabase>(
            builder: (context, db, _) {
              if (db.unreadNotificationCount > 0) {
                return TextButton(
                  onPressed: () => db.markAllNotificationsAsRead(),
                  child: const Text('Mark all read'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (db.notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Use the public refreshData method instead of private _loadNotifications
              await db.refreshData();
            },
            child: ListView.builder(
              itemCount: db.notifications.length,
              itemBuilder: (context, index) {
                final notification = db.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _handleNotificationTap(
                    context,
                    notification,
                    db,
                  ), // Pass context
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
    TaskDatabase db,
  ) {
    // Add context parameter
    // Mark as read if not already
    if (!notification.isRead) {
      db.markNotificationAsRead(notification.id);
    }

    // Handle navigation based on notification type
    switch (notification.type) {
      case 'task_assigned':
        // Navigate to tasks tab
        Navigator.pop(context);
        break;
      case 'task_completed':
        // Navigate to tasks tab
        Navigator.pop(context);
        break;
      case 'team_invitation':
        // Navigate to invitations page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TeamInvitationsPage()),
        );
        break;
      case 'team_member_joined':
        // Navigate to team selection
        Navigator.pop(context);
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
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
