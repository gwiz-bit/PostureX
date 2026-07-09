import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/score_ring.dart';
import '../widgets/section_card.dart';
import '../widgets/weekly_bar_chart.dart';

class _MuscleGroup {
  const _MuscleGroup({required this.name, required this.score, required this.color});

  final String name;
  final int score;
  final Color color;
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static const _weekData = [
    DayScore(day: 'M', value: 90),
    DayScore(day: 'T', value: 79),
    DayScore(day: 'W'),
    DayScore(day: 'T', value: 76),
    DayScore(day: 'F'),
    DayScore(day: 'S', value: 76),
    DayScore(day: 'S'),
  ];

  static const _muscleGroups = [
    _MuscleGroup(name: 'Back', score: 66, color: AppColors.chartOrange),
    _MuscleGroup(name: 'Chest', score: 80, color: AppColors.chartBlue),
    _MuscleGroup(name: 'Core', score: 90, color: AppColors.chartGreen),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Progress',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Posture',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your lifetime average',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const ScoreRing(score: 80, label: 'Score', size: 108, strokeWidth: 9),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: const [
                          _StatRow(label: 'Best session', value: '90'),
                          SizedBox(height: 14),
                          _StatRow(label: 'Total sets', value: '14'),
                          SizedBox(height: 14),
                          _StatRow(label: 'Total volume', value: '5.4k'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Trend',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Posture score by day',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const WeeklyBarChart(data: _weekData),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'By Muscle Group',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Where your form shines — or slips',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                for (final group in _muscleGroups) ...[
                  _MuscleGroupBar(group: group),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MuscleGroupBar extends StatelessWidget {
  const _MuscleGroupBar({required this.group});

  final _MuscleGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            group.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: group.score / 100,
              minHeight: 10,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(group.color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '${group.score}',
            textAlign: TextAlign.right,
            style: TextStyle(color: group.color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
