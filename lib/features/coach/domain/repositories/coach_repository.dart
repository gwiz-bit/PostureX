import '../entities/chat_message.dart';

abstract class CoachRepository {
  /// Sends [message] with the prior conversation [history] and returns the
  /// model's reply text. History is kept client-side only — the backend
  /// doesn't persist it.
  Future<String> sendMessage({required String message, required List<ChatMessage> history});
}
