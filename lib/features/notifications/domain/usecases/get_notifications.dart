import '../entities/notification.dart';
import '../repositories/notification_repository.dart';

class GetNotifications {
  const GetNotifications(this._repository);

  final NotificationRepository _repository;

  Future<List<AppNotification>> call() => _repository.getNotifications();
}
