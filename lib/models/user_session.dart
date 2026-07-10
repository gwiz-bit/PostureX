import 'onboarding_profile.dart';
import 'workout_plan.dart';

/// App-wide holder for the signed-in user's profile.
/// A lightweight static session (no backend) — populated once onboarding
/// completes, and read by Home/Profile so the rest of the app reflects the
/// data the user actually entered instead of hardcoded placeholders.
class UserSession {
  UserSession._();

  static const _defaultName = 'Athlete';
  static const _defaultHeightCm = 178;
  static const _defaultWeightKg = 75;
  static const _defaultAge = 26;
  static const _defaultWeeklyGoal = 4;
  static const _defaultFitnessLevel = 'Regular';
  static const _defaultFocusAreas = {'Full body'};

  static String name = _defaultName;
  static int heightCm = _defaultHeightCm;
  static int weightKg = _defaultWeightKg;
  static int age = _defaultAge;
  static int weeklyGoal = _defaultWeeklyGoal;
  static String fitnessLevel = _defaultFitnessLevel;
  static Set<String> focusAreas = {..._defaultFocusAreas};

  static bool isSignedIn = false;
  static bool hasCompletedOnboarding = false;

  /// Populated once the app authenticates against the real backend
  /// (see ApiClient/TokenStorage). `null` means no backend session yet.
  static String? accessToken;
  static int? userId;
  static String? email;

  static WorkoutPlan plan = WorkoutPlan.generate(
    workoutDays: const {},
    weeklyGoal: _defaultWeeklyGoal,
    focusAreas: _defaultFocusAreas,
    fitnessLevel: _defaultFitnessLevel,
  );

  static void completeOnboarding({
    required String name,
    required OnboardingProfile profile,
  }) {
    UserSession.name = name;
    heightCm = profile.heightCm;
    weightKg = profile.currentWeightKg;
    age = profile.age;
    weeklyGoal = profile.workoutsPerWeek;
    fitnessLevel = profile.fitnessLevel;
    focusAreas = profile.focusAreas.isEmpty ? {'Full body'} : profile.focusAreas;
    plan = WorkoutPlan.generate(
      workoutDays: profile.workoutDays,
      weeklyGoal: weeklyGoal,
      focusAreas: focusAreas,
      fitnessLevel: fitnessLevel,
    );
    isSignedIn = true;
    hasCompletedOnboarding = true;
  }

  /// Applies a real backend session obtained via ApiClient.login/register +
  /// fetchMe. Does not touch onboarding-only fields (height/weight/etc.) —
  /// those have no backend equivalent and stay whatever they already are.
  static void applyAuthSession({
    required int userId,
    required String email,
    required String? fullName,
    required String accessToken,
  }) {
    UserSession.userId = userId;
    UserSession.email = email;
    UserSession.accessToken = accessToken;
    if (fullName != null && fullName.trim().isNotEmpty) {
      UserSession.name = fullName;
    }
    isSignedIn = true;
  }

  static void logOut() {
    name = _defaultName;
    heightCm = _defaultHeightCm;
    weightKg = _defaultWeightKg;
    age = _defaultAge;
    weeklyGoal = _defaultWeeklyGoal;
    fitnessLevel = _defaultFitnessLevel;
    focusAreas = {..._defaultFocusAreas};
    plan = WorkoutPlan.generate(
      workoutDays: const {},
      weeklyGoal: _defaultWeeklyGoal,
      focusAreas: _defaultFocusAreas,
      fitnessLevel: _defaultFitnessLevel,
    );
    isSignedIn = false;
    hasCompletedOnboarding = false;
    accessToken = null;
    userId = null;
    email = null;
  }
}
