import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/squat_error_tips.dart';
import '../widgets/section_card.dart';

/// Shown after "End Session" instead of the old small confirmation dialog
/// — adds a most-frequent-errors breakdown (with a matching improvement
/// tip per category) on top of the reps/duration/accuracy the dialog
/// already had.
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.exercise,
    required this.repCount,
    required this.durationSeconds,
    required this.accuracyScore,
    required this.errorCounts,
  });

  final String exercise;
  final int repCount;
  final double durationSeconds;
  final double? accuracyScore;

  /// Keyed by category (see [categorizeSquatError]), not raw message —
  /// already deduplicated by the caller.
  final Map<String, int> errorCounts;

  @override
  Widget build(BuildContext context) {
    final sortedErrors = errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            const Text(
              'Session complete',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _capitalize(exercise),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _StatTile(value: '$repCount', label: 'Reps')),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(value: '${durationSeconds.round()}s', label: 'Duration'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: accuracyScore == null ? '—' : '${accuracyScore!.round()}%',
                    label: 'Accuracy',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Most common mistakes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (sortedErrors.isEmpty)
              SectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.chartGreen, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No technique errors this session — great form!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              SectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < sortedErrors.length; i++) ...[
                      if (i > 0) const Divider(color: AppColors.border, height: 1),
                      _ErrorTipRow(
                        category: sortedErrors[i].key,
                        count: sortedErrors[i].value,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTipRow extends StatelessWidget {
  const _ErrorTipRow({required this.category, required this.count});

  final String category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tip = tipForCategory(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tip?.label ?? category,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '×$count',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 4),
            Text(
              tip.tip,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
