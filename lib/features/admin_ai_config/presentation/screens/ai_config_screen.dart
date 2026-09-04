import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../theme/admin_theme.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/admin/common_widgets.dart';
import '../../admin_ai_config_module.dart';
import '../../domain/entities/posture_rules.dart';
import 'exercise_rules_screen.dart';

/// Chọn bài tập để chỉnh ngưỡng phân tích tư thế.
///
/// Màn hình cũ ở đây là 7 thanh trượt ghi cứng cho squat, đọc/ghi một biến nằm
/// trong RAM của server. Ba vấn đề của nó:
///
///   1. Mất sạch mỗi lần restart server, không cảnh báo gì.
///   2. Nó sửa hằng số toàn cục của module `squat`, tức sửa MẶC ĐỊNH của
///      SquatAnalyzer — nên chỉnh cho một bài là đổi luôn cả 21 biến thể squat.
///   3. Chỉ squat chỉnh được; 8 analyzer còn lại không có đường vào.
///
/// Bản này liệt kê mọi bài có analyzer (khoảng 106 bài) và ghi thẳng vào bảng
/// `ExercisePostureRules` — đúng bảng backend đọc khi mở phiên phân tích.
class AIConfigScreen extends StatefulWidget {
  const AIConfigScreen({super.key});

  @override
  State<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends State<AIConfigScreen> {
  List<TunableExercise>? _exercises;
  bool _isLoading = true;
  String? _errorMessage;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await AdminAiConfigModule.listExercises()(search: _search);
      if (!mounted) return;
      setState(() => _exercises = list);
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

  /// Gõ tới đâu gọi tới đó sẽ bắn một request mỗi ký tự. Chờ 350 ms sau lần gõ
  /// cuối mới gọi.
  void _onSearchChanged(String value) {
    _search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _openExercise(TunableExercise exercise) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExerciseRulesScreen(
          exerciseId: exercise.id,
          exerciseName: exercise.name,
        ),
      ),
    );
    // Quay lại thì nạp lại danh sách: số ngưỡng ghi đè có thể vừa đổi.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('AI Analysis Config', 'Ngưỡng phân tích theo từng bài tập'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm bài tập...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
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

    final exercises = _exercises ?? const <TunableExercise>[];
    if (exercises.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Không có bài tập nào khớp.\n\nChỉ bài có analyzer mới chỉnh được ngưỡng — '
            'bài không phân tích được thì không có gì để chỉnh.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kMuted, height: 1.5),
          ),
        ),
      );
    }

    final daChinh = exercises.where((e) => e.overrideCount > 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        SectionLabel('${exercises.length} bài phân tích được · $daChinh bài đã chỉnh riêng'),
        ListCard(
          rows: [
            for (final e in exercises) _ExerciseRow(exercise: e, onTap: () => _openExercise(e)),
          ],
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.onTap});

  final TunableExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Tên bài có thể rất dài ("Chest Supported Dumbbell Row"), nên phải
            // co lại được — môi trường test không nạp font thật nên chữ đo ra
            // rộng hơn máy thật và từng làm tràn Row ở chỗ khác.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(fontSize: 13, color: kInk, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise.analyzer,
                    style: const TextStyle(fontSize: 11, color: kMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (exercise.overrideCount > 0)
              StatusBadge('${exercise.overrideCount} ngưỡng riêng', kAmberBg, kAmber)
            else
              const StatusBadge('Mặc định', kGrayBg, kGrayFg),
            const Icon(Icons.chevron_right, size: 18, color: kMuted),
          ],
        ),
      ),
    );
  }
}
