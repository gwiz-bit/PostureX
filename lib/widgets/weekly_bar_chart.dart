import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DayScore {
  const DayScore({required this.day, this.value});

  final String day;
  final int? value;
}

/// Bar chart showing a daily score across the week, with "-" for days
/// that have no logged data yet.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.data,
    this.maxValue = 100,
    this.barHeight = 90,
  });

  final List<DayScore> data;
  final int maxValue;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in data)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DayBar(entry: entry, maxValue: maxValue, barHeight: barHeight),
            ),
          ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.entry, required this.maxValue, required this.barHeight});

  final DayScore entry;
  final int maxValue;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final hasValue = entry.value != null;
    final fraction = hasValue ? (entry.value! / maxValue).clamp(0.06, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hasValue ? '${entry.value}' : '-',
          style: TextStyle(
            color: hasValue ? AppColors.primary : AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: barHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: hasValue ? fraction : 0.03,
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: hasValue ? AppColors.primary : AppColors.track,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.day,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
