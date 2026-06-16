import 'package:flutter/material.dart';
import 'package:momentum/components/notification_tile.dart';
import 'package:momentum/components/responsive_layout.dart';
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
                  onPressed: db.markAllNotificationsAsRead,
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

          return ResponsiveBody(
            child: RefreshIndicator(
              onRefresh: db.refreshData,
              child: ListView.builder(
                itemCount: db.notifications.length,
                itemBuilder: (context, i) {
                  final notification = db.notifications[i];
                  return NotificationTile(
                    notification: notification,
                    onTap: () => _handleTap(context, notification, db),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    AppNotification notification,
    TaskDatabase db,
  ) {
    if (!notification.isRead) db.markNotificationAsRead(notification.id);
    switch (notification.type) {
      case 'team_invitation':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeamInvitationsPage()),
        );
        break;
      default:
        Navigator.pop(context);
    }
  }
}
