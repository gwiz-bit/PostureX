import '../../../../services/api_client.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/chat_message.dart';

class CoachRemoteDataSource {
  const CoachRemoteDataSource(this._client);

  final ApiClient _client;

  Future<String> sendMessage({required String message}) {
    return _client.sendCoachMessage(message: message);
  }

  /// Streams reply chunks from the SSE endpoint. Falls back to the regular
  /// non-streaming endpoint (yields the full reply as one chunk) when the
  /// SSE endpoint is unavailable — e.g. the server hasn't been deployed with
  /// the streaming route yet, or returns 503/504 at the connection level.
  Stream<String> sendMessageStream({required String message}) async* {
    try {
      await for (final chunk in _client.sendCoachMessageStream(message: message)) {
        yield chunk;
      }
    } on ApiException {
      // SSE endpoint unavailable — fall back to the regular endpoint.
      final reply = await _client.sendCoachMessage(message: message);
      yield reply;
    }
  }

  Future<List<ChatMessage>> fetchHistory() => _client.fetchCoachHistory();

  Future<void> clearHistory() => _client.clearCoachHistory();

  Future<void> reportMessage({required String reason, required String content}) {
    return _client.reportCoachMessage(reason: reason, content: content);
  }
}
