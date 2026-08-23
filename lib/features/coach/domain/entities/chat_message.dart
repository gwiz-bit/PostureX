/// One turn of the AI Coach conversation — `role` is `'user'` or `'model'`,
/// matching the backend's `ChatMessage` schema (mirrors Gemini's role
/// vocabulary directly, no translation layer needed).
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}
