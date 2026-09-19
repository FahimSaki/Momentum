import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:momentum/blocs/notification_state.dart';
import 'package:momentum/models/app_notification.dart';
import 'package:momentum/services/notification_service.dart';

/// Owns the in-app notification list and unread count.
///
/// Same behavior as the NotificationBloc this replaces — every event
/// handler's body moved directly into a public method, with the
/// Completer/stream.first bridging removed entirely, since Cubit's
/// emit() can already be called from anywhere. loadNotifications() now
/// just does the work and returns when it's actually done.
///
/// Owns its own NotificationService instance rather than sharing
/// TaskCubit's FCM-only instance, on purpose — TaskCubit's instance also
/// drives FCM/local-notification setup via .init(), guarded by an
/// instance-level flag. A second instance calling .init() would redo FCM
/// permission requests and re-register message listeners. This class
/// only ever calls the purely additive updateToken(), never init().
class NotificationCubit extends Cubit<NotificationState> {
  final Logger _logger = Logger();
  final NotificationService _service = NotificationService();

  NotificationCubit() : super(const NotificationState());

  /// Sets the auth token — called directly by TaskCubit as part of
  /// initializeSession(), before any load happens.
  void setToken(String jwtToken) {
    _service.updateToken(jwtToken);
  }

  Future<void> loadNotifications() async {
    try {
      final notifs = await _service.getNotifications();
      emit(
        state.copyWith(
          notifications: notifs,
          unreadCount: notifs.where((n) => !n.isRead).length,
        ),
      );
    } catch (e, stackTrace) {
      _logger.w(
        'Error loading notifications (non-critical)',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          unreadCount: state.notifications.where((n) => !n.isRead).length,
        ),
      );
    }
  }

  /// Replaces `context.read<NotificationBloc>().add(NotificationMarkedAsRead(id))`.
  Future<void> markAsRead(String notificationId) async {
    try {
      final updated = await _service.markAsRead(notificationId);
      final index = state.notifications.indexWhere(
        (n) => n.id == notificationId,
      );
      if (index == -1) return;

      final updatedList = List<AppNotification>.from(state.notifications);
      updatedList[index] = updated ?? _markRead(updatedList[index]);

      emit(
        NotificationState(
          notifications: updatedList,
          unreadCount: updatedList.where((n) => !n.isRead).length,
        ),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error marking notification as read',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Replaces `context.read<NotificationBloc>().add(const AllNotificationsMarkedAsRead())`.
  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      final updatedList = state.notifications
          .map((n) => n.isRead ? n : _markRead(n))
          .toList();
      emit(NotificationState(notifications: updatedList, unreadCount: 0));
    } catch (e, stackTrace) {
      _logger.e(
        'Error marking all notifications as read',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Replaces `context.read<NotificationBloc>().add(const NotificationsCleared())`.
  /// Only ever called internally by TaskCubit.clearData() — not a
  /// consumer-facing change.
  void clear() {
    emit(const NotificationState());
  }

  AppNotification _markRead(AppNotification n) => AppNotification(
    id: n.id,
    recipient: n.recipient,
    sender: n.sender,
    team: n.team,
    task: n.task,
    type: n.type,
    title: n.title,
    message: n.message,
    data: n.data,
    isRead: true,
    readAt: DateTime.now(),
    createdAt: n.createdAt,
  );
}
