import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../models/workout_plan.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../utils/app_locale.dart';
import '../widgets/app_logo.dart';
import '../features/admin_dashboard/presentation/screens/home_screen.dart' as admin;
import '../features/auth/presentation/screens/login_screen.dart';
import 'main_shell.dart';

/// First screen shown on launch — animates the PostureX mark and wordmark
/// in, then hands off to [LoginScreen] automatically after a short pause.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, AppLocaleMixin {
  // Runs for the full time the splash is on screen; the entrance animation
  // only occupies the first slice of it (see _scale/_fade below), then holds
  // until the controller completes and hands off to LoginScreen.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );

  // Kicked off in parallel with the entrance animation so a stored session
  // (if any) is ready to check by the time the animation completes.
  late final Future<bool> _sessionRestored = _restoreSession();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatusChanged);
  }

  /// Attempts to restore a persisted backend session. Any failure (no
  /// stored token, expired/invalid token, network error, or — in the
  /// widget-test harness — a MissingPluginException from secure storage
  /// having no platform implementation) is treated the same: fall back to
  /// the Login screen, exactly like a fresh install.
  Future<bool> _restoreSession() async {
    try {
      final stored = await TokenStorage.readSession();
      if (stored == null) return false;

      UserSession.accessToken = stored.accessToken;
      final profile = await ApiClient.instance
          .fetchMe()
          .timeout(const Duration(seconds: 5));
      UserSession.applyAuthSession(
        userId: profile.id,
        email: profile.email,
        fullName: profile.fullName,
        accessToken: stored.accessToken,
        isAdmin: profile.isAdmin,
      );
      UserSession.hasCompletedOnboarding = true;
      try {
        final p = await TokenStorage.readPlanParams();
        if (p != null) {
          UserSession.weeklyGoal = p.weeklyGoal;
          UserSession.fitnessLevel = p.fitnessLevel;
          UserSession.workoutDays = p.workoutDays;
          UserSession.focusAreas = p.focusAreas.isEmpty ? {'Full body'} : p.focusAreas;
          UserSession.equipment = p.equipment;
          UserSession.goals = p.goals;
          UserSession.healthIssues = p.healthIssues;
        } else {
          // Fallback: restore at least weeklyGoal + fitnessLevel from backend
          final pd = await ApiClient.instance
              .fetchProfile()
              .timeout(const Duration(seconds: 5));
          if (pd.weeklyGoal != null) UserSession.weeklyGoal = pd.weeklyGoal!;
          if (pd.fitnessLevel != null) UserSession.fitnessLevel = pd.fitnessLevel!;
        }
        UserSession.plan = WorkoutPlan.generate(
          workoutDays: UserSession.workoutDays,
          weeklyGoal: UserSession.weeklyGoal,
          focusAreas: UserSession.focusAreas,
          fitnessLevel: UserSession.fitnessLevel,
          equipment: UserSession.equipment,
          goals: UserSession.goals,
          healthIssues: UserSession.healthIssues,
        );
        // Re-apply AI Coach modifications saved from the previous session.
        // Days are matched by date — if the reference week shifted (opened a
        // week later), dates won't match and this is a safe no-op.
        final aiDays = await TokenStorage.readAiPlanDays();
        if (aiDays != null) {
          final byDate = {
            for (final d in aiDays)
              DateTime(d.date.year, d.date.month, d.date.day): d,
          };
          final planDays = UserSession.plan.days;
          for (var i = 0; i < planDays.length; i++) {
            final key = DateTime(
              planDays[i].date.year,
              planDays[i].date.month,
              planDays[i].date.day,
            );
            final saved = byDate[key];
            if (saved != null) planDays[i] = saved;
          }
        }
      } catch (_) {}
      return true;
    } catch (_) {
      UserSession.accessToken = null;
      return false;
    }
  }

  void _onStatusChanged(AnimationStatus status) async {
    if (status != AnimationStatus.completed || !mounted) return;
    final restored = await _sessionRestored;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) {
          if (!restored) return const LoginScreen();
          return UserSession.isAdmin ? const admin.HomeScreen() : const MainShell();
        },
      ),
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
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(child: AppLogo(size: 48, color: AppColors.primary)),
                ),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Posture',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'X',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocale.t('splash_tagline'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
