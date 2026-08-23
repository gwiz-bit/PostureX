import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/score_ring.dart';
import '../../../../widgets/section_card.dart';
import '../../../../widgets/weekly_bar_chart.dart';
import '../../domain/entities/workout.dart';
import '../../workout_module.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen> {
  final _controller = WorkoutModule.controller();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Public so [MainShell] can force a fresh fetch when this tab is
  /// selected — see [ProfileScreenState.reload] for why.
  Future<void> reload() => _controller.load();

  List<DayScore> _weeklyTrend() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final workouts = _controller.workouts;

    return List.generate(7, (i) {
      final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final dayScores = [
        for (final w in workouts)
          if (w.accuracyScore != null &&
              w.startedAt.year == day.year &&
              w.startedAt.month == day.month &&
              w.startedAt.day == day.day)
            w.accuracyScore!,
      ];
      final value = dayScores.isEmpty
          ? null
          : (dayScores.reduce((a, b) => a + b) / dayScores.length).round();
      return DayScore(day: labels[i], value: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final stats = _controller.stats;
          final overallScore = stats.averageAccuracy?.round() ?? 0;
          final workouts = _controller.workouts;

          return RefreshIndicator(
            onRefresh: _controller.load,
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
                if (_controller.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (_controller.errorMessage != null)
                  SectionCard(
                    child: Column(
                      children: [
                        Text(
                          _controller.errorMessage!,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _controller.load, child: const Text('Retry')),
                      ],
                    ),
                  )
                else ...[
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
                            ScoreRing(score: overallScore, label: 'Score', size: 108, strokeWidth: 9),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  _StatRow(
                                    label: 'Best session',
                                    value: stats.bestAccuracy == null
                                        ? '—'
                                        : '${stats.bestAccuracy!.round()}',
                                  ),
                                  const SizedBox(height: 14),
                                  _StatRow(label: 'Total sessions', value: '${stats.sessionCount}'),
                                  const SizedBox(height: 14),
                                  _StatRow(label: 'Total reps', value: '${stats.totalReps}'),
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
                        WeeklyBarChart(data: _weeklyTrend()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Workouts',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your latest logged sessions',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (workouts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No sessions logged yet — start a workout to see it here.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          )
                        else
                          for (final workout in workouts.take(10)) ...[
                            _WorkoutRow(workout: workout),
                            const Divider(color: AppColors.border, height: 1),
                          ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final date = workout.startedAt;
    final dateLabel = '${date.month}/${date.day}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.exercise[0].toUpperCase() + workout.exercise.substring(1),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel · ${workout.totalReps} reps',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (workout.accuracyScore != null)
            Text(
              '${workout.accuracyScore!.round()}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
