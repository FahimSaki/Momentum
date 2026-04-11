import 'package:flutter/material.dart';

class NotificationTile extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

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
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  notification.timeAgo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (notification.sender != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    notification.sender!.name,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: onTap,
        trailing: notification.isRead
            ? null
            : const SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
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
