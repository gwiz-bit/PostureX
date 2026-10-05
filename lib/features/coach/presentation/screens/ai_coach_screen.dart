import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../coach_module.dart';
import '../../domain/entities/chat_message.dart';

/// Chat with the AI Coach — personalized training/nutrition advice backed
/// by the real user profile + workout history (see `POST /api/v1/coach/chat`).
/// The server persists history (`coach_messages` table) and restores it on
/// open — see CHANGELOG 11/09/2026.
class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> with AppLocaleMixin {
  final _controller = CoachModule.controller();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
    if (_controller.planMessage != null) {
      _controller.clearPlanMessage();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t('home_ai_plan_ready'))),
      );
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocale.t('coach_clear_confirm_title'),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          AppLocale.t('coach_clear_confirm_body'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text(AppLocale.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(AppLocale.t('coach_clear_chat')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.clear();
  }

  Future<void> _reportMessage(String content) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocale.t('coach_report_title'),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              AppLocale.t('coach_report_body'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          for (final r in const ['inappropriate', 'inaccurate', 'unsafe', 'other'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(r),
              child: Text(
                AppLocale.t('coach_report_$r'),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    final sent = await _controller.report(reason: reason, content: content);
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t('coach_report_sent'))),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await _controller.send(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _controller.messages;
    final showPlanButton = _controller.showPlanSuggestion && !_controller.isSending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          AppLocale.t('coach_title'),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: AppLocale.t('coach_generate_plan'),
            onPressed: _controller.isGeneratingPlan ? null : _controller.generatePlan,
            icon: _controller.isGeneratingPlan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          ),
          if (messages.isNotEmpty)
            IconButton(
              tooltip: AppLocale.t('coach_clear_chat'),
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_controller.isLoadingHistory)
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                minHeight: 2,
              ),
            const _DisclaimerBanner(),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(onSuggestionTap: (text) {
                      _inputController.text = text;
                      _send();
                    })
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length +
                          (_controller.isSending ? 1 : 0) +
                          (showPlanButton ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= messages.length) {
                          if (_controller.isSending) return const _TypingBubble();
                          return _ApplyPlanButton(onTap: () {
                            _controller.dismissPlanSuggestion();
                            _controller.generatePlan();
                          });
                        }
                        final message = messages[index];
                        return _ChatBubble(
                          message: message,
                          onReport: message.isUser ? null : () => _reportMessage(message.content),
                        );
                      },
                    ),
            ),
            if (_controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _controller.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: AppLocale.t('coach_hint'),
                          hintStyle: const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _controller.isSending ? null : _send,
                        icon: const Icon(Icons.send_rounded, color: AppColors.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onReport});

  final ChatMessage message;

  /// Set only for AI replies — opens the report dialog (Google Play requires an
  /// in-app way to report AI-generated content).
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isUser ? AppColors.onPrimary : AppColors.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bubble,
            if (onReport != null)
              Tooltip(
                message: AppLocale.t('coach_report'),
                child: InkWell(
                  onTap: onReport,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(6, 6, 10, 2),
                    child: Icon(Icons.flag_outlined, size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible notice that AI Coach is an AI, not a doctor — Google Play's
/// health/AI content policies expect this on a health-adjacent AI chatbot.
class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocale.t('coach_disclaimer'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  static const _suggestions = [
    'Gợi ý chế độ tập 4 buổi/tuần cho người mới',
    'Ăn gì trước và sau khi tập gym?',
    'Tôi nên tập bao nhiêu protein mỗi ngày?',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text(
            AppLocale.t('coach_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          for (final s in _suggestions) ...[
            _SuggestionChip(text: s, onTap: () => onSuggestionTap(s)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
    );
  }
}

/// Button shown below the last AI reply when the user's message was detected
/// as a plan-request. Tapping it dismisses the suggestion and triggers
/// [generateAndApplyAiPlan] — the AppBar ✨ spinner reflects the loading state.
class _ApplyPlanButton extends StatelessWidget {
  const _ApplyPlanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Áp dụng vào lịch tập'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
    );
  }
}
