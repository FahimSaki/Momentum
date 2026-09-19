import 'package:momentum/models/app_notification.dart';

/// Immutable snapshot of in-app notification state — replaces the
/// `notifications` / `unreadNotificationCount` fields that used to live
/// directly on TaskDatabase.
class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
