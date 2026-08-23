import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_all_notifications_read.dart';
import '../../domain/usecases/mark_notification_read.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required GetNotifications getNotifications,
    required MarkNotificationRead markNotificationRead,
    required MarkAllNotificationsRead markAllNotificationsRead,
  })  : _getNotifications = getNotifications,
        _markNotificationRead = markNotificationRead,
        _markAllNotificationsRead = markAllNotificationsRead;

  final GetNotifications _getNotifications;
  final MarkNotificationRead _markNotificationRead;
  final MarkAllNotificationsRead _markAllNotificationsRead;

  bool isLoading = true;
  String? errorMessage;
  List<AppNotification> notifications = const [];

  /// Set once anything was marked read, so `NotificationsScreen` can tell
  /// the caller (Home's bell badge) to refresh — `UserSession` has no
  /// listener so it can't do this on its own.
  bool didChangeAnything = false;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      notifications = await _getNotifications();
    } catch (_) {
      errorMessage = 'Could not load your notifications.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Optimistic update: flips the UI immediately and rolls back if the
  /// request fails — marking read is cheap, waiting for the round-trip
  /// first would make every tap feel laggy.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final index = notifications.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;

    notifications = [...notifications];
    notifications[index] = notification.copyWith(isRead: true);
    didChangeAnything = true;
    notifyListeners();

    try {
      await _markNotificationRead(notification.id);
    } on AppFailure {
      notifications = [...notifications];
      notifications[index] = notification;
      notifyListeners();
    } catch (_) {
      notifications = [...notifications];
      notifications[index] = notification;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final previous = notifications;
    notifications = [for (final n in notifications) n.copyWith(isRead: true)];
    didChangeAnything = true;
    notifyListeners();

    try {
      await _markAllNotificationsRead();
    } catch (_) {
      notifications = previous;
      notifyListeners();
    }
  }
}
