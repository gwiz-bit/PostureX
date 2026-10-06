import '../entities/chat_message.dart';

abstract class CoachRepository {
  /// Sends [message] and returns the model's reply text. The server keeps
  /// conversation history itself (`coach_messages` table) — callers no
  /// longer track/pass it.
  Future<String> sendMessage({required String message});

  /// Streaming version: yields text chunks as the AI generates them.
  /// First token arrives in ~1 second; history is saved server-side after
  /// the stream completes, same as [sendMessage].
  Stream<String> sendMessageStream({required String message});

  /// Full chat history, oldest first.
  Future<List<ChatMessage>> fetchHistory();

  /// Permanently deletes the user's chat history.
  Future<void> clearHistory();

  /// Reports an AI reply. [reason] is one of `inappropriate`, `inaccurate`,
  /// `unsafe`, `other`.
  Future<void> reportMessage({required String reason, required String content});
}
