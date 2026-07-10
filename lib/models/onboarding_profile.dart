/// Mutable bag of answers collected across the onboarding flow.
/// Shared by reference across all step widgets.
class OnboardingProfile {
  Set<String> goals = {};
  String gender = 'Male';
  String motivation = 'Health and wellness';
  Set<String> focusAreas = {};
  String fitnessLevel = 'Beginner';
  String activityLevel = 'Moderate active';
  int heightCm = 168;
  int age = 22;
  int currentWeightKg = 60;
  int targetWeightKg = 65;
  Set<String> healthIssues = {};
  Set<String> equipment = {};
  int workoutsPerWeek = 4;
  Set<String> workoutDays = {};
  bool reminderEnabled = true;
}
