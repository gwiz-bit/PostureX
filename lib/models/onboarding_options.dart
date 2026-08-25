/// Numeric bounds and plain option lists used only within the onboarding
/// questionnaire (`lib/screens/onboarding/onboarding_flow.dart`) — pulled
/// out of the step widget call sites so they're named constants instead of
/// magic numbers/literal lists repeated inline.
class OnboardingOptions {
  const OnboardingOptions._();

  static const ageMin = 14;
  static const ageMax = 90;
  static const workoutsPerWeekMin = 1;
  static const workoutsPerWeekMax = 7;

  static const goals = [
    'Improve posture',
    'Build muscle',
    'Burn fat',
    'Increase endurance',
    'Boost mental strength',
    'Weight loss',
    'Balance',
    'Flexibility',
    'Relieve stress',
    'Optimize workouts',
    'Agility',
    'Reduce back pain',
  ];

  static const focusAreas = [
    'Back',
    'Arm',
    'Shoulder',
    'Abs',
    'Chest',
    'Leg',
    'Glutes',
    'Full body',
  ];

  static const healthIssues = [
    'Back or hernia',
    'Arms and shoulders',
    'Hip joints',
    'Knee',
    'Post-injury recovery',
  ];

  static const equipment = [
    'Full gym',
    'Barbells',
    'Dumbbells',
    'Kettlebells',
    'Resistance bands',
    'Machines',
  ];
}
