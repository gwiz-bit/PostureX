import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../theme/admin_theme.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/admin/common_widgets.dart';
import '../../../../widgets/admin/dialogs.dart';
import '../../admin_ai_config_module.dart';
import '../../domain/entities/posture_rules.dart';

/// Chỉnh ngưỡng phân tích của MỘT bài tập.
///
/// Không có ô nào ghi cứng ở đây — nhãn, mặc định và khoảng hợp lệ đều đến từ
/// backend (`app/ml/analyzers/tunables.py`), nên bài dùng analyzer nào thì hiện
/// đúng bộ ngưỡng của analyzer đó. Màn hình cũ ghi cứng 5 thanh trượt squat,
/// nên 8 analyzer còn lại không chỉnh được gì.
class ExerciseRulesScreen extends StatefulWidget {
  const ExerciseRulesScreen({super.key, required this.exerciseId, required this.exerciseName});

  final int exerciseId;
  final String exerciseName;

  @override
  State<ExerciseRulesScreen> createState() => _ExerciseRulesScreenState();
}

class _ExerciseRulesScreenState extends State<ExerciseRulesScreen> {
  ExerciseRules? _rules;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  /// Đã đụng vào gì chưa — để cảnh báo khi thoát mà chưa lưu.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rules = await AdminAiConfigModule.getRules()(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _isDirty = false;
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final rules = _rules;
    if (rules == null) return;
    setState(() => _isSaving = true);
    try {
      final saved = await AdminAiConfigModule.saveRules()(rules.exerciseId, rules.overrides);
      if (!mounted) return;
      setState(() {
        _rules = saved;
        _isDirty = false;
      });
      showToast(context, 'Đã lưu — áp dụng cho phiên tập mới của "${saved.exerciseName}"');
    } on AppFailure catch (e) {
      // Với lỗi 422, `e.message` là câu backend giải thích ngưỡng nào sai và
      // khoảng hợp lệ là bao nhiêu — dài nhưng đúng thứ admin cần để sửa, nên
      // hiện nguyên văn trong hộp thoại thay vì cắt ngắn vào toast.
      if (mounted) await _showError(e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showError(String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không lưu được'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      );

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    return showConfirmDialog(
      context,
      'Bỏ thay đổi?',
      'Các ngưỡng vừa chỉnh chưa được lưu.',
    );
  }

  void _update(Tunable tunable, {double? value, bool reset = false}) {
    setState(() {
      _rules = _rules!.withTunable(
        reset ? tunable.copyWith(clearCurrent: true) : tunable.copyWith(current: value),
      );
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!discard || !context.mounted) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: adminAppBar(widget.exerciseName, _rules?.analyzer ?? 'Ngưỡng phân tích'),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMessage != null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ]),
        ),
      ]);
    }

    final rules = _rules!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ExplainerCard(),
        const SizedBox(height: 16),
        const SectionLabel('Ngưỡng góc'),
        WhiteCard(
          child: Column(
            children: [
              for (final t in rules.tunables) _TunableRow(tunable: t, onChanged: _update),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: _isSaving ? 'Đang lưu...' : 'Lưu ngưỡng',
          onPressed: _isSaving ? () {} : _save,
        ),
      ],
    );
  }
}

/// Giải thích cơ chế mặc định/ghi đè — thứ quyết định admin hiểu đúng màn này.
class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard();

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: kBlue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ngưỡng để "Mặc định" thì dùng giá trị chung của analyzer. Chỉnh một '
              'ngưỡng ở đây chỉ áp cho riêng bài này — các biến thể khác cùng '
              'analyzer không đổi theo.',
              style: TextStyle(fontSize: 12, color: kMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TunableRow extends StatelessWidget {
  const _TunableRow({required this.tunable, required this.onChanged});

  final Tunable tunable;
  final void Function(Tunable, {double? value, bool reset}) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = tunable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nhãn có thể dài; `Expanded` + ellipsis vì môi trường test không nạp
          // font thật nên chữ đo ra rộng hơn máy thật và làm tràn Row.
          Row(
            children: [
              Expanded(
                child: Text(
                  t.label,
                  style: const TextStyle(fontSize: 13, color: kInk),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // Đơn vị đến từ backend, không ghi cứng "°": `knee_overshoot`
                // là tỉ lệ theo chiều rộng khung hình chứ không phải góc.
                t.format(t.effective),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // `Wrap` chứ không phải `Row`: hai huy hiệu cộng lại (badge "Đã
          // chỉnh · mặc định 95°" + "Ảnh hưởng đếm rep") tràn ra ngoài trên
          // máy thật — font thật rộng hơn font thay thế trong môi trường
          // test, nên `flutter test` không bắt được, phải bấm tay mới lộ ra.
          // `Wrap` tự xuống dòng thay vì tràn, nên không có ngưỡng bề rộng
          // nào làm hỏng lại được.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (t.isOverridden)
                StatusBadge('Đã chỉnh · mặc định ${t.format(t.defaultValue)}', kAmberBg, kAmber)
              else
                const StatusBadge('Mặc định', kGrayBg, kGrayFg),
              if (t.affectsRepCount) const StatusBadge('Ảnh hưởng đếm rep', kBlueBg, kBlue),
            ],
          ),
          if (t.isOverridden)
            Align(
              alignment: Alignment.centerRight,
              // TextButton chứ không phải GhostButton dùng chung: cái kia đặt
              // `width: double.infinity` nên nhét vào hàng ngang là tràn ngay.
              child: TextButton(
                onPressed: () => onChanged(t, reset: true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: kBlue,
                ),
                child: const Text('Về mặc định', style: TextStyle(fontSize: 12)),
              ),
            ),
          Slider(
            value: t.effective.clamp(t.minimum, t.maximum),
            min: t.minimum,
            max: t.maximum,
            // Bước nhảy do backend quy định: 1° cho ngưỡng góc (dưới 1° không
            // có ý nghĩa thực tế, và `RepCounter` còn biên dung sai 10° quanh
            // đáy), 0.01 cho tỉ lệ — dùng chung bước 1 cho một khoảng 0–0.3
            // sẽ cho thanh trượt chỉ nhảy được giữa 0 và 1.
            divisions: t.divisions,
            activeColor: AppColors.primary,
            onChanged: (v) => onChanged(t, value: v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.format(t.minimum), style: const TextStyle(fontSize: 11, color: kMuted)),
              Text(t.format(t.maximum), style: const TextStyle(fontSize: 11, color: kMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
