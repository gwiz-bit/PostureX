import '../../../../services/api_client.dart';
import '../../domain/entities/chat_message.dart';

class CoachRemoteDataSource {
  const CoachRemoteDataSource(this._client);

  final ApiClient _client;

  Future<String> sendMessage({required String message, required List<ChatMessage> history}) {
    return _client.sendCoachMessage(message: message, history: history);
  }
}
