import '../../../../services/api_client.dart';
import '../../domain/entities/notification.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AppNotification>> fetchNotifications() => _client.fetchNotifications();

  Future<AppNotification> markNotificationRead(int id) => _client.markNotificationRead(id);

  Future<void> markAllNotificationsRead() => _client.markAllNotificationsRead();
}
