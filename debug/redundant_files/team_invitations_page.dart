import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/notification_cubit.dart';
import 'package:momentum/blocs/notification_state.dart';
import 'package:momentum/blocs/task_cubit.dart';
import 'package:momentum/components/notification_tile.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/models/app_notification.dart';

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
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              if (state.unreadCount > 0) {
                return TextButton(
                  onPressed: () =>
                      context.read<NotificationCubit>().markAllAsRead(),
                  child: const Text('Mark all read'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          if (state.notifications.isEmpty) {
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
              onRefresh: context.read<TaskCubit>().refreshData,
              child: ListView.builder(
                itemCount: state.notifications.length,
                itemBuilder: (context, i) {
                  final notification = state.notifications[i];
                  return NotificationTile(
                    notification: notification,
                    onTap: () => _handleTap(context, notification),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, AppNotification notification) {
    if (!notification.isRead) {
      context.read<NotificationCubit>().markAsRead(notification.id);
    }
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
