import '../entities/broadcast_history_item.dart';

abstract class AdminNotificationRepository {
  Future<List<BroadcastHistoryItem>> getBroadcastHistory();

  /// Returns the number of recipients the broadcast was sent to.
  Future<int> sendBroadcast({required String title, String? body});
}
