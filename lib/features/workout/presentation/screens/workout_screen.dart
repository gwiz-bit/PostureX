import 'package:flutter/material.dart';

import '../../../../models/user_session.dart';
import '../../../../models/workout_plan.dart';
import '../../../../screens/analyze_session_screen.dart';
import '../../../../services/token_storage.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/app_logo.dart';
import '../../../exercises/presentation/screens/exercises_screen.dart';


class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with AppLocaleMixin {
  String? _activeExercise;
  Set<String> _completedToday = {};

  @override
  void initState() {
    super.initState();
    _loadCompleted();
    UserSession.planVersion.addListener(_onPlanChanged);
  }

  void _onPlanChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UserSession.planVersion.removeListener(_onPlanChanged);
    super.dispose();
  }

  Future<void> _loadCompleted() async {
    try {
      final stored = await TokenStorage.readCompletedExercises();
      if (stored != null && mounted) {
        setState(() => _completedToday = stored);
      }
    } catch (_) {}
  }

  Future<void> _startAnalyzeSession(String exerciseName) async {
    setState(() => _activeExercise = exerciseName);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyzeSessionScreen(exercise: exerciseName.toLowerCase()),
        maintainState: false,
      ),
    );
    if (!mounted) return;
    final updated = {..._completedToday, exerciseName};
    setState(() {
      _activeExercise = null;
      _completedToday = updated;
    });
    try {
      await TokenStorage.saveCompletedExercises(names: updated);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            AppLocale.t('workout_title'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          _TodaySessionCard(
            onStartExercise: _startAnalyzeSession,
            activeExercise: _activeExercise,
            completedExercises: _completedToday,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExercisesScreen()),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(AppLocale.t('workout_upload_video')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's session card — reads UserSession.plan live each build
// ---------------------------------------------------------------------------

class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({
    required this.onStartExercise,
    required this.activeExercise,
    required this.completedExercises,
  });

  final Future<void> Function(String exerciseName) onStartExercise;
  final String? activeExercise;
  final Set<String> completedExercises;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayPlan = UserSession.plan.planFor(today);
    final dateLabel =
        '${_weekdayNames[today.weekday - 1]}, ${_monthNames[today.month - 1]} ${today.day}';

    if (dayPlan == null || dayPlan.isRestDay) {
      DayPlan? next;
      for (final day in UserSession.plan.days) {
        if (!day.isRestDay &&
            day.date.isAfter(DateTime(today.year, today.month, today.day))) {
          next = day;
          break;
        }
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Rest Day',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.self_improvement_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recover, stretch, and get ready for your next session.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Next: ${next.sessionName} on '
                      '${_weekdayNames[next.date.weekday - 1]}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final allDone = dayPlan.exercises.isNotEmpty &&
        dayPlan.exercises.every((e) => completedExercises.contains(e.name));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(dayPlan.sessionName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (allDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text('Done',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < dayPlan.exercises.length; i++) ...[
            _ExerciseRow(
              exercise: dayPlan.exercises[i],
              isActive: activeExercise == dayPlan.exercises[i].name,
              isDone: completedExercises.contains(dayPlan.exercises[i].name),
              onStart: () => onStartExercise(dayPlan.exercises[i].name),
            ),
            if (i != dayPlan.exercises.length - 1)
              const Divider(color: AppColors.border, height: 1),
          ],
          if (dayPlan.nutritionTip != null &&
              dayPlan.nutritionTip!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.restaurant_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dayPlan.nutritionTip!,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single exercise row with active / done state
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.isActive,
    required this.isDone,
    required this.onStart,
  });

  final PlannedExercise exercise;
  final bool isActive;
  final bool isDone;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (isDone)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16)
          else
            AppLogo(size: 16, color: isDone ? Colors.green : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exercise.name,
              style: TextStyle(
                  color: isDone
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null),
            ),
          ),
          Text(
            exercise.setsReps,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: isActive
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : isDone
                    ? const Icon(Icons.replay_rounded,
                        color: AppColors.textSecondary, size: 20)
                    : IconButton(
                        onPressed: onStart,
                        icon: const Icon(Icons.play_circle_filled_rounded,
                            color: AppColors.primary, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Start',
                      ),
          ),
        ],
      ),
    );
  }
}
