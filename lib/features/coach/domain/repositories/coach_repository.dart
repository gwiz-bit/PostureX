import '../entities/chat_message.dart';

abstract class CoachRepository {
  /// Sends [message] and returns the model's reply text. The server keeps
  /// conversation history itself (`coach_messages` table) — callers no
  /// longer track/pass it.
  Future<String> sendMessage({required String message});

  /// Full chat history, oldest first.
  Future<List<ChatMessage>> fetchHistory();

  /// Permanently deletes the user's chat history.
  Future<void> clearHistory();
}
