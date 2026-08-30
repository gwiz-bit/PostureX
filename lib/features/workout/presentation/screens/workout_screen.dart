import 'package:flutter/material.dart';

import '../../../../screens/analyze_session_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_logo.dart';
import '../../../../widgets/icon_badge.dart';
import '../../../../widgets/section_card.dart';
import '../../../video/presentation/screens/upload_video_screen.dart';

/// One exercise within a [_Routine] — [label] is what's shown to the user,
/// [key] is the lowercase string sent to the backend's analyzer registry
/// (see `ANALYZER_REGISTRY` in `app/api/v1/routes/realtime.py`) and used to
/// match an admin-uploaded guide video by exercise name.
class _RoutineExercise {
  const _RoutineExercise(this.label, this.key);

  final String label;
  final String key;
}

class _Routine {
  const _Routine({
    required this.name,
    required this.exercises,
    required this.icon,
    this.useLogo = false,
  });

  final String name;
  final List<_RoutineExercise> exercises;
  final IconData icon;
  final bool useLogo;

  String get subtitle => exercises.map((e) => e.label).join(' · ');
}

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  static const _routines = [
    _Routine(
      name: 'Full Body Check',
      icon: Icons.accessibility_new_rounded,
      exercises: [
        _RoutineExercise('Squat', 'squat'),
        _RoutineExercise('Row', 'row'),
        _RoutineExercise('Bench', 'dumbbell bench press'),
        _RoutineExercise('Plank', 'plank'),
      ],
    ),
    _Routine(
      name: 'Posture Primer',
      icon: Icons.self_improvement_rounded,
      exercises: [
        _RoutineExercise('Cat-Cow', 'cat-cow'),
        _RoutineExercise('Plank', 'plank'),
        _RoutineExercise('Lunge', 'lunge'),
      ],
    ),
    _Routine(
      name: 'Strength Foundations',
      icon: Icons.fitness_center_rounded,
      useLogo: true,
      exercises: [
        _RoutineExercise('Deadlift', 'deadlift'),
        _RoutineExercise('OHP', 'barbell overhead press'),
        _RoutineExercise('Hip Thrust', 'hip thrust'),
      ],
    ),
  ];

  void _startAnalyzeSession(BuildContext context, String exerciseKey) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzeSessionScreen(exercise: exerciseKey)),
    );
  }

  /// Each routine bundles several exercises — let the user pick which one
  /// to check now instead of always jumping into the first/a fixed one.
  /// Every exercise listed here has a real backend analyzer (see
  /// `ANALYZER_REGISTRY`), so whichever one is picked gets genuine
  /// rep-counting + form feedback, not a silent squat fallback.
  void _pickExercise(BuildContext context, _Routine routine) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                routine.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final exercise in routine.exercises)
              ListTile(
                leading: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
                title: Text(
                  exercise.label,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _startAnalyzeSession(context, exercise.key);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Workout',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Active Workout',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start a new session or pick exercises\nto begin recording your sets.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startAnalyzeSession(context, 'squat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start Empty Workout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload a video instead'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Suggested Routines',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap a routine, then pick which exercise to check',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final routine in _routines) ...[
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () => _pickExercise(context, routine),
              child: Row(
                children: [
                  IconBadge(
                    icon: routine.icon,
                    customIcon: routine.useLogo ? const AppLogo() : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          routine.subtitle,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
