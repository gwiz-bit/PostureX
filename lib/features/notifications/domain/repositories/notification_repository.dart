import '../entities/notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();

  Future<AppNotification> markRead(int id);

  Future<void> markAllRead();
}
