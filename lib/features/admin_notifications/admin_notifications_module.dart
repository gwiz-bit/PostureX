import '../../services/api_client.dart';
import 'data/datasources/admin_notification_remote_data_source.dart';
import 'data/repositories/admin_notification_repository_impl.dart';
import 'domain/repositories/admin_notification_repository.dart';
import 'domain/usecases/get_broadcast_history.dart';
import 'domain/usecases/send_broadcast.dart';

class AdminNotificationsModule {
  AdminNotificationsModule._();

  static AdminNotificationRepository _repository() =>
      AdminNotificationRepositoryImpl(AdminNotificationRemoteDataSource(ApiClient.instance));

  static GetBroadcastHistory getBroadcastHistory() => GetBroadcastHistory(_repository());

  static SendBroadcast sendBroadcast() => SendBroadcast(_repository());
}
