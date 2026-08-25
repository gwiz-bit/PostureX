/// Mutable bag of answers collected across the onboarding flow.
/// Shared by reference across all step widgets.
class OnboardingProfile {
  // TODO(onboarding-audit): collected but never read anywhere else in the
  // app and never sent to the backend — either wire it into WorkoutPlan
  // generation / personalization, or drop the "Choose your goals" step.
  Set<String> goals = {};

  String? gender;

  // TODO(onboarding-audit): collected but never read anywhere else in the
  // app and never sent to the backend — either use it to tailor AI Coach
  // messaging, or drop the "What motivates your exercise?" step.
  String? motivation;

  Set<String> focusAreas = {};

  String? fitnessLevel;

  // TODO(onboarding-audit): collected but never read anywhere else in the
  // app and never sent to the backend — either factor it into
  // WorkoutPlan.generate's session templating, or drop this step.
  String? activityLevel;

  int heightCm = 168;
  int age = 22;
  int currentWeightKg = 60;

  // TODO(onboarding-audit): collected but never sent to the backend or read
  // anywhere else — Progress/Profile only ever show current weight, never
  // a target. Either wire it into a "weight goal" progress indicator, or
  // drop the "What is your target weight?" step.
  int targetWeightKg = 65;

  // TODO(onboarding-audit): collected but never read anywhere else in the
  // app — no exercise filtering/warning uses this today. Either wire it
  // into exercise recommendations/analyzer warnings, or drop this step.
  Set<String> healthIssues = {};

  // TODO(onboarding-audit): collected but never read anywhere else in the
  // app — no exercise filtering uses this today. Either wire it into
  // exercise recommendations, or drop this step.
  Set<String> equipment = {};

  int workoutsPerWeek = 4;
  Set<String> workoutDays = {};

  // TODO(onboarding-audit): set here but never read afterwards — no
  // reminder/notification path in the app checks this flag today (the
  // backend's scheduled reminders run unconditionally for every user).
  // Either gate reminder sending on this flag, or drop the "Reminder"
  // toggle on the final step.
  bool reminderEnabled = true;
}
