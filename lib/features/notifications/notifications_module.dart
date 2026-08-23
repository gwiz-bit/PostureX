import '../../services/api_client.dart';
import 'data/datasources/notification_remote_data_source.dart';
import 'data/repositories/notification_repository_impl.dart';
import 'domain/repositories/notification_repository.dart';
import 'domain/usecases/get_notifications.dart';
import 'domain/usecases/mark_all_notifications_read.dart';
import 'domain/usecases/mark_notification_read.dart';
import 'presentation/controllers/notifications_controller.dart';

/// Manual composition root for the Notifications feature.
class NotificationsModule {
  NotificationsModule._();

  static NotificationRepository _repository() =>
      NotificationRepositoryImpl(NotificationRemoteDataSource(ApiClient.instance));

  static NotificationsController controller() => NotificationsController(
        getNotifications: GetNotifications(_repository()),
        markNotificationRead: MarkNotificationRead(_repository()),
        markAllNotificationsRead: MarkAllNotificationsRead(_repository()),
      );
}
