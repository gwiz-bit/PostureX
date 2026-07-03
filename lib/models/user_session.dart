import 'onboarding_profile.dart';

/// App-wide holder for the signed-in user's profile.
/// A lightweight static session (no backend) — populated once onboarding
/// completes, and read by Home/Profile so the rest of the app reflects the
/// data the user actually entered instead of hardcoded placeholders.
class UserSession {
  UserSession._();

  static String name = 'Athlete';
  static int heightCm = 178;
  static int weightKg = 75;
  static int age = 26;
  static int weeklyGoal = 4;
  static String fitnessLevel = 'Regular';
  static Set<String> focusAreas = {'Back', 'Core', 'Legs'};

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
    hasCompletedOnboarding = true;
  }
}
