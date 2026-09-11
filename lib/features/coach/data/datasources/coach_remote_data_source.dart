import '../../../../services/api_client.dart';
import '../../domain/entities/chat_message.dart';

class CoachRemoteDataSource {
  const CoachRemoteDataSource(this._client);

  final ApiClient _client;

  Future<String> sendMessage({required String message}) {
    return _client.sendCoachMessage(message: message);
  }

  Future<List<ChatMessage>> fetchHistory() => _client.fetchCoachHistory();

  Future<void> clearHistory() => _client.clearCoachHistory();
}
