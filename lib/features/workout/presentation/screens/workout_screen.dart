import 'package:flutter/material.dart';

import '../../../../screens/analyze_session_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/app_logo.dart';
import '../../../../widgets/icon_badge.dart';
import '../../../../widgets/section_card.dart';
import '../../../exercises/presentation/screens/exercises_screen.dart';

/// One exercise within a [_Routine] — [label] is what's shown to the user,
/// [key] is the lowercase string sent to the backend's analyzer registry
/// (see `ANALYZER_REGISTRY` in `app/api/v1/routes/realtime.py`) and used to
/// match an admin-uploaded guide video by exercise name.
///
/// [key] must be the FULL library exercise name (e.g. "barbell bent over
/// row"), not a bare analyzer alias (e.g. "row") — `AnalyzeSessionScreen`
/// looks up the demo video by an EXACT, case-insensitive match against
/// `Exercises.ExerciseName`, and a bare alias (though a perfectly valid
/// `ANALYZER_REGISTRY` key on its own) matches no real library row, so the
/// video silently never loads (confirmed 11/09/2026 real-device test: Row/
/// Plank/Lunge/Deadlift/Hip Thrust showed no guide video). Picking any one
/// variant already registered to the intended analyzer (see the
/// `_ROW_VARIANTS`/`_PLANK_VARIANTS`/etc. comments in registry.py) fixes
/// both the video AND keeps analyzer selection correct — it does not need
/// to be the "canonical" name of the exercise family, just A name that maps
/// to the right analyzer and has a demo video on the server.
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

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with AppLocaleMixin {
  static const _routines = [
    _Routine(
      name: 'Full Body Check',
      icon: Icons.accessibility_new_rounded,
      exercises: [
        _RoutineExercise('Squat', 'squat'),
        _RoutineExercise('Row', 'barbell bent over row'),
        _RoutineExercise('Bench', 'dumbbell bench press'),
        _RoutineExercise('Plank', 'front plank'),
      ],
    ),
    _Routine(
      name: 'Posture Primer',
      icon: Icons.self_improvement_rounded,
      exercises: [
        // Cat-Cow has NO exercise in the library at all (see
        // `_CAT_COW_VARIANTS` in registry.py: "Thư viện hiện KHÔNG có bài
        // nào thuộc họ này") — no demo video exists to link to, not a bug
        // to fix here. Left as-is; flagged 11/09/2026 for a product call on
        // whether to source a video or drop it from this routine.
        _RoutineExercise('Cat-Cow', 'cat-cow'),
        _RoutineExercise('Plank', 'front plank'),
        _RoutineExercise('Lunge', 'forward lunge'),
      ],
    ),
    _Routine(
      name: 'Strength Foundations',
      icon: Icons.fitness_center_rounded,
      useLogo: true,
      exercises: [
        _RoutineExercise('Deadlift', 'barbell deadlift'),
        _RoutineExercise('OHP', 'barbell overhead press'),
        _RoutineExercise('Hip Thrust', 'barbell hip thrust'),
      ],
    ),
  ];

  void _startAnalyzeSession(String exerciseKey) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzeSessionScreen(exercise: exerciseKey)),
    );
  }

  /// Each routine bundles several exercises — let the user pick which one
  /// to check now instead of always jumping into the first/a fixed one.
  /// Every exercise listed here has a real backend analyzer (see
  /// `ANALYZER_REGISTRY`), so whichever one is picked gets genuine
  /// rep-counting + form feedback, not a silent squat fallback.
  void _pickExercise(_Routine routine) {
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
                  _startAnalyzeSession(exercise.key);
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
          Text(
            AppLocale.t('workout_title'),
            style: const TextStyle(
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
              Text(
                AppLocale.t('workout_no_active_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocale.t('workout_no_active_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startAnalyzeSession('squat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    AppLocale.t('workout_start_empty'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                // No exercise is selected at this point — send the user to
                // pick one first (each exercise's detail screen has its own
                // "Upload a video instead" that carries the right name
                // along). Used to push straight to `UploadVideoScreen()`
                // with no exercise at all, which silently hardcoded
                // `exercise: 'squat'` in the upload call — every uploaded
                // video got analyzed as a squat regardless of what was
                // actually in it (found 11/09/2026 testing B Stance Hip
                // Thrust, which came back with squat feedback).
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExercisesScreen()),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(AppLocale.t('workout_upload_video')),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            AppLocale.t('workout_suggested_routines'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocale.t('workout_routines_hint'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final routine in _routines) ...[
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () => _pickExercise(routine),
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
