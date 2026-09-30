import 'package:flutter/material.dart';

import '../../models/user_session.dart';
import '../../models/workout_plan.dart';
import '../../services/api_client.dart';
import '../../services/token_storage.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_locale.dart';
import '../main_shell.dart';

/// Brief animated "building your plan" pause shown right after onboarding
/// finishes — mirrors the AI-plan-generation step in the reference flow —
/// then hands off to the app with the plan already generated and stored in
/// [UserSession].
class PlanGeneratingScreen extends StatefulWidget {
  const PlanGeneratingScreen({super.key});

  @override
  State<PlanGeneratingScreen> createState() => _PlanGeneratingScreenState();
}

class _PlanGeneratingScreenState extends State<PlanGeneratingScreen>
    with SingleTickerProviderStateMixin, AppLocaleMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  List<ServerExercise>? _serverExercises;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatusChanged);
    _loadExercises();
  }

  // Fire-and-forget: fetches the exercise library so the plan can be
  // personalized by equipment and focus areas before the user reaches Home.
  // Any failure is silently ignored — the hardcoded plan from completeOnboarding
  // is already set in UserSession and will be used as the fallback.
  Future<void> _loadExercises() async {
    try {
      final raw = await ApiClient.instance
          .fetchExercises()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      _serverExercises = raw
          .map((e) => (
                name: e.name,
                muscleGroups: e.muscleGroups,
                difficulty: e.difficulty,
                supportsAnalysis: e.supportsAnalysis,
              ))
          .toList();
    } catch (_) {
      // Proceed with hardcoded plan.
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _rebuildPlanIfReady();
    TokenStorage.savePlanParams(
      workoutDays: UserSession.workoutDays,
      weeklyGoal: UserSession.weeklyGoal,
      fitnessLevel: UserSession.fitnessLevel,
      focusAreas: UserSession.focusAreas,
      equipment: UserSession.equipment,
      goals: UserSession.goals,
      healthIssues: UserSession.healthIssues,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  // Rebuilds UserSession.plan using server exercises if they loaded in time.
  // No-op if _serverExercises is null (fetch failed or still in flight).
  void _rebuildPlanIfReady() {
    final exercises = _serverExercises;
    if (exercises == null || exercises.isEmpty) return;
    UserSession.plan = WorkoutPlan.generate(
      workoutDays: UserSession.workoutDays,
      weeklyGoal: UserSession.weeklyGoal,
      focusAreas: UserSession.focusAreas,
      fitnessLevel: UserSession.fitnessLevel,
      equipment: UserSession.equipment,
      goals: UserSession.goals,
      healthIssues: UserSession.healthIssues,
      serverExercises: exercises,
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final percent = (_controller.value * 100).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.track,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    AppLocale.t('plan_gen_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    AppLocale.t('plan_gen_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
