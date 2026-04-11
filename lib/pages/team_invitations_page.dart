import 'package:flutter/material.dart';
import 'package:momentum/components/notification_tile.dart';
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
      ),
      body: Consumer<TaskDatabase>(
        builder: (context, db, _) {
          if (db.notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return RefreshIndicator(
            onRefresh: () => db.refreshData(),
            child: ListView.builder(
              itemCount: db.notifications.length,
              itemBuilder: (context, index) {
                final notification = db.notifications[index];

                return NotificationTile(
                  notification: notification,
                  onTap: () =>
                      _handleNotificationTap(context, notification, db),
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
    if (!notification.isRead) {
      db.markNotificationAsRead(notification.id);
    }

    Navigator.pop(context);
  }
}
