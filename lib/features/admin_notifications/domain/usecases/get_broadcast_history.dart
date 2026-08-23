import '../entities/broadcast_history_item.dart';
import '../repositories/admin_notification_repository.dart';

class GetBroadcastHistory {
  const GetBroadcastHistory(this._repository);

  final AdminNotificationRepository _repository;

  Future<List<BroadcastHistoryItem>> call() => _repository.getBroadcastHistory();
}
