import 'onboarding_profile.dart';

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
  static const _defaultFocusAreas = {'Back', 'Core', 'Legs'};

  static String name = _defaultName;
  static int heightCm = _defaultHeightCm;
  static int weightKg = _defaultWeightKg;
  static int age = _defaultAge;
  static int weeklyGoal = _defaultWeeklyGoal;
  static String fitnessLevel = _defaultFitnessLevel;
  static Set<String> focusAreas = {..._defaultFocusAreas};

  static bool isSignedIn = false;
  static bool hasCompletedOnboarding = false;

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
    isSignedIn = true;
    hasCompletedOnboarding = true;
  }

  /// Mock Google sign-in — no real OAuth/backend, just marks the session
  /// as signed in under the Google account's display name.
  static void signInWithGoogle({String name = 'Google User'}) {
    UserSession.name = name;
    isSignedIn = true;
    hasCompletedOnboarding = true;
  }

  static void logOut() {
    name = _defaultName;
    heightCm = _defaultHeightCm;
    weightKg = _defaultWeightKg;
    age = _defaultAge;
    weeklyGoal = _defaultWeeklyGoal;
    fitnessLevel = _defaultFitnessLevel;
    focusAreas = {..._defaultFocusAreas};
    isSignedIn = false;
    hasCompletedOnboarding = false;
  }
}
