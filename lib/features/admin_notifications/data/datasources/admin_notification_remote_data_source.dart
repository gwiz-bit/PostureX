import '../../../../services/api_client.dart';
import '../../domain/entities/broadcast_history_item.dart';

class AdminNotificationRemoteDataSource {
  const AdminNotificationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<BroadcastHistoryItem>> fetchBroadcastHistory() => _client.fetchBroadcastHistory();

  Future<int> sendBroadcast({required String title, String? body}) {
    return _client.sendBroadcast(title: title, body: body);
  }
}
