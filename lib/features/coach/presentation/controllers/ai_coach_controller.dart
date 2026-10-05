import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../utils/ai_plan_apply.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/clear_coach_history.dart';
import '../../domain/usecases/fetch_coach_history.dart';
import '../../domain/usecases/send_coach_message.dart';

class AiCoachController extends ChangeNotifier {
  AiCoachController({
    required this._sendCoachMessage,
    required this._fetchCoachHistory,
    required this._clearCoachHistory,
  }) {
    _loadHistory();
  }

  final SendCoachMessage _sendCoachMessage;
  final FetchCoachHistory _fetchCoachHistory;
  final ClearCoachHistory _clearCoachHistory;

  final List<ChatMessage> messages = [];
  bool isLoadingHistory = true;
  bool isSending = false;
  bool isGeneratingPlan = false;
  String? errorMessage;
  String? planMessage;

  /// True khi tin nhắn user vừa gửi chứa intent xin lịch tập —
  /// screen sẽ hiện nút "Áp dụng vào lịch tập" dưới reply AI cuối.
  bool showPlanSuggestion = false;

  /// The server is now the source of truth for history (see CHANGELOG
  /// 11/09/2026) — restore it once when the controller is created, instead
  /// of every screen visit starting blank.
  Future<void> _loadHistory() async {
    try {
      final history = await _fetchCoachHistory();
      messages.addAll(history);
    } catch (_) {
      // Best-effort: an empty chat that still works to send NEW messages
      // beats a broken screen just because history failed to load once.
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || isSending) return;

    messages.add(ChatMessage(role: 'user', content: text));
    isSending = true;
    showPlanSuggestion = false; // reset trước mỗi lần gửi
    errorMessage = null;
    notifyListeners();

    try {
      final reply = await _sendCoachMessage(message: text);
      messages.add(ChatMessage(role: 'model', content: reply));
      showPlanSuggestion = _isPlanRequest(text);
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void dismissPlanSuggestion() {
    showPlanSuggestion = false;
    notifyListeners();
  }

  /// Phát hiện intent xin tư vấn / cập nhật lịch tập qua từ khoá.
  static bool _isPlanRequest(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      // Tiếng Việt
      'lịch tập', 'giáo án', 'chương trình tập', 'kế hoạch tập',
      'tạo lịch', 'cập nhật lịch', 'gợi ý lịch', 'lên lịch',
      'thay đổi lịch', 'điều chỉnh lịch', 'xây dựng lịch',
      'chế độ tập', 'buổi tập', 'lịch gym', 'lịch tập luyện',
      'chương trình luyện tập', 'kế hoạch luyện tập',
      // English
      'workout plan', 'training plan', 'exercise plan',
      'workout schedule', 'training schedule', 'training program',
      'create plan', 'make plan', 'update plan', 'suggest plan',
    ];
    return keywords.any(lower.contains);
  }

  /// One-shot consume so the screen shows the "plan ready" confirmation
  /// exactly once instead of re-showing it on every unrelated rebuild.
  void clearPlanMessage() {
    planMessage = null;
  }

  Future<void> clear() async {
    try {
      await _clearCoachHistory();
      messages.clear();
      errorMessage = null;
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      notifyListeners();
    }
  }

  /// Generates a plan from `POST /coach/plan` — which now also reads recent
  /// chat context server-side — and applies it to the Home calendar. This
  /// is the "connect chat with the training plan" entry point (see
  /// CHANGELOG 11/09/2026): before, generating a plan only existed as a
  /// button on Home, unrelated to anything discussed here.
  Future<void> generatePlan() async {
    if (isGeneratingPlan) return;
    isGeneratingPlan = true;
    errorMessage = null;
    planMessage = null;
    notifyListeners();

    try {
      await generateAndApplyAiPlan();
      planMessage = 'ready';
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isGeneratingPlan = false;
      notifyListeners();
    }
  }
}
