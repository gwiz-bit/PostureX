import '../entities/notification.dart';
import '../repositories/notification_repository.dart';

class MarkNotificationRead {
  const MarkNotificationRead(this._repository);

  final NotificationRepository _repository;

  Future<AppNotification> call(int id) => _repository.markRead(id);
}
