import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/send_coach_message.dart';

class AiCoachController extends ChangeNotifier {
  AiCoachController({required SendCoachMessage sendCoachMessage})
      : _sendCoachMessage = sendCoachMessage;

  final SendCoachMessage _sendCoachMessage;

  final List<ChatMessage> messages = [];
  bool isSending = false;
  String? errorMessage;

  Future<void> send(String text) async {
    if (text.trim().isEmpty || isSending) return;

    final history = List<ChatMessage>.from(messages);
    messages.add(ChatMessage(role: 'user', content: text));
    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      final reply = await _sendCoachMessage(message: text, history: history);
      messages.add(ChatMessage(role: 'model', content: reply));
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}
