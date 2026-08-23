import '../repositories/notification_repository.dart';

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repository);

  final NotificationRepository _repository;

  Future<void> call() => _repository.markAllRead();
}
