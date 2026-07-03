import 'package:flutter/material.dart';

import '../../models/onboarding_profile.dart';
import '../../models/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/onboarding/checkbox_list_step.dart';
import '../../widgets/onboarding/multi_select_chip_step.dart';
import '../../widgets/onboarding/number_wheel_step.dart';
import '../../widgets/onboarding/single_select_card_step.dart';
import '../../widgets/onboarding/single_select_list_step.dart';
import '../../widgets/onboarding/workout_days_step.dart';
import '../../widgets/onboarding/workout_frequency_step.dart';
import '../main_shell.dart';

/// Post-signup questionnaire that collects the fitness profile used to
/// personalize Home/Progress/Profile — mirrors the multi-step onboarding
/// pattern (progress bar, one question per screen) while keeping this
/// app's own coral-dark visual language.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.name});

  final String name;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const totalSteps = 14;

  final OnboardingProfile _profile = OnboardingProfile();
  int _index = 0;

  void _next() => setState(() => _index++);

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _index--);
    }
  }

  void _finish(Set<String> days, bool reminderEnabled) {
    _profile.workoutDays = days;
    _profile.reminderEnabled = reminderEnabled;
    UserSession.completeOnboarding(name: widget.name, profile: _profile);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = <Widget>[
      MultiSelectChipStep(
        key: ValueKey(1),
        step: 1,
        totalSteps: totalSteps,
        title: 'Choose your goals',
        options: const [
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
        ],
        initialSelected: _profile.goals,
        onBack: _back,
        onContinue: (value) {
          _profile.goals = value;
          _next();
        },
      ),
      SingleSelectListStep(
        key: ValueKey(2),
        step: 2,
        totalSteps: totalSteps,
        title: 'Choose your gender',
        options: const [
          SingleSelectOption(
            value: 'Female',
            label: 'Female',
            trailing: Icon(Icons.female_rounded, color: AppColors.textSecondary, size: 24),
          ),
          SingleSelectOption(
            value: 'Male',
            label: 'Male',
            trailing: Icon(Icons.male_rounded, color: AppColors.textSecondary, size: 24),
          ),
          SingleSelectOption(
            value: 'Other',
            label: 'Other',
            trailing: Icon(Icons.transgender_rounded, color: AppColors.textSecondary, size: 24),
          ),
        ],
        initialValue: _profile.gender,
        onBack: _back,
        onContinue: (value) {
          _profile.gender = value;
          _next();
        },
      ),
      SingleSelectListStep(
        key: ValueKey(3),
        step: 3,
        totalSteps: totalSteps,
        title: 'What motivates your exercise?',
        options: const [
          SingleSelectOption(value: 'Better posture', label: 'Better posture', trailing: Text('🧍', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Health and wellness', label: 'Health and wellness', trailing: Text('💪', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Weight management', label: 'Weight management', trailing: Text('🍏', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Achievement and progress', label: 'Achievement and progress', trailing: Text('🥇', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Social support', label: 'Social support', trailing: Text('🤝', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Stress relief', label: 'Stress relief', trailing: Text('🌿', style: TextStyle(fontSize: 22))),
          SingleSelectOption(value: 'Enjoyment', label: 'Enjoyment', trailing: Text('🎉', style: TextStyle(fontSize: 22))),
        ],
        initialValue: _profile.motivation,
        onBack: _back,
        onContinue: (value) {
          _profile.motivation = value;
          _next();
        },
      ),
      MultiSelectChipStep(
        key: ValueKey(4),
        step: 4,
        totalSteps: totalSteps,
        title: 'Choose your focus areas',
        options: const ['Back', 'Arm', 'Shoulder', 'Abs', 'Chest', 'Leg', 'Glutes', 'Full body'],
        initialSelected: _profile.focusAreas,
        onBack: _back,
        onContinue: (value) {
          _profile.focusAreas = value;
          _next();
        },
      ),
      SingleSelectCardStep(
        key: ValueKey(5),
        step: 5,
        totalSteps: totalSteps,
        title: 'Choose your fitness level',
        options: const [
          SelectCardOption(
            value: 'Beginner',
            label: 'Beginner',
            description: "I'm new or have only tried it for a bit",
            icon: Icons.star_border_rounded,
          ),
          SelectCardOption(
            value: 'Intermediate',
            label: 'Intermediate',
            description: "I've lifted weights before",
            icon: Icons.star_half_rounded,
          ),
          SelectCardOption(
            value: 'Advanced',
            label: 'Advanced',
            description: "I've stuck to a balanced routine for years!",
            icon: Icons.star_rounded,
          ),
        ],
        initialValue: _profile.fitnessLevel,
        onBack: _back,
        onContinue: (value) {
          _profile.fitnessLevel = value;
          _next();
        },
      ),
      SingleSelectCardStep(
        key: ValueKey(6),
        step: 6,
        totalSteps: totalSteps,
        title: 'Choose your activity level',
        options: const [
          SelectCardOption(
            value: 'Sedentary',
            label: 'Sedentary',
            description: 'Little or no exercise, office job',
            icon: Icons.chair_outlined,
          ),
          SelectCardOption(
            value: 'Light active',
            label: 'Light active',
            description: 'Light exercise/sports 1-3 days/week',
            icon: Icons.directions_walk_rounded,
          ),
          SelectCardOption(
            value: 'Moderate active',
            label: 'Moderate active',
            description: 'Moderate exercise/sports 3-5 days/week',
            icon: Icons.directions_run_rounded,
          ),
          SelectCardOption(
            value: 'Very active',
            label: 'Very active',
            description: 'Hard exercise 6-7 days/week',
            icon: Icons.whatshot_rounded,
          ),
          SelectCardOption(
            value: 'Extra active',
            label: 'Extra active',
            description: 'Very hard exercise & physical job',
            icon: Icons.bolt_rounded,
          ),
        ],
        initialValue: _profile.activityLevel,
        onBack: _back,
        onContinue: (value) {
          _profile.activityLevel = value;
          _next();
        },
      ),
      NumberWheelStep(
        key: ValueKey(7),
        step: 7,
        totalSteps: totalSteps,
        title: 'How tall are you?',
        unit: 'cm',
        min: 140,
        max: 220,
        initialValue: _profile.heightCm,
        tipEmoji: '🧐',
        tipTitle: 'Calculating your BMI',
        tipBody: 'We use your height to personalize your posture and fitness insights.',
        onBack: _back,
        onContinue: (value) {
          _profile.heightCm = value;
          _next();
        },
      ),
      NumberWheelStep(
        key: ValueKey(8),
        step: 8,
        totalSteps: totalSteps,
        title: 'How old are you?',
        unit: '',
        min: 14,
        max: 90,
        initialValue: _profile.age,
        tipEmoji: '🚀',
        tipTitle: 'Personalized for your age',
        tipBody: 'Age helps us tailor session intensity and recovery to you.',
        onBack: _back,
        onContinue: (value) {
          _profile.age = value;
          _next();
        },
      ),
      NumberWheelStep(
        key: ValueKey(9),
        step: 9,
        totalSteps: totalSteps,
        title: 'What is your current weight?',
        unit: 'kg',
        min: 35,
        max: 180,
        initialValue: _profile.currentWeightKg,
        tipEmoji: '💪',
        tipTitle: 'Track your progress over time',
        tipBody: 'We use your weight to personalize load recommendations and track trends.',
        onBack: _back,
        onContinue: (value) {
          _profile.currentWeightKg = value;
          _next();
        },
      ),
      NumberWheelStep(
        key: ValueKey(10),
        step: 10,
        totalSteps: totalSteps,
        title: 'What is your target weight?',
        unit: 'kg',
        min: 35,
        max: 180,
        initialValue: _profile.targetWeightKg,
        tipEmoji: '🏆',
        tipTitle: 'Set a realistic goal',
        tipBody: 'Small, steady changes lead to lasting results — you can adjust this anytime.',
        onBack: _back,
        onContinue: (value) {
          _profile.targetWeightKg = value;
          _next();
        },
      ),
      CheckboxListStep(
        key: ValueKey(11),
        step: 11,
        totalSteps: totalSteps,
        title: 'Any health issues?',
        options: const [
          'Back or hernia',
          'Arms and shoulders',
          'Hip joints',
          'Knee',
          'Post-injury recovery',
        ],
        initialSelected: _profile.healthIssues,
        onBack: _back,
        onContinue: (value) {
          _profile.healthIssues = value;
          _next();
        },
      ),
      CheckboxListStep(
        key: ValueKey(12),
        step: 12,
        totalSteps: totalSteps,
        title: 'What equipment do you have?',
        options: const [
          'Full gym',
          'Barbells',
          'Dumbbells',
          'Kettlebells',
          'Resistance bands',
          'Machines',
        ],
        initialSelected: _profile.equipment,
        onBack: _back,
        onContinue: (value) {
          _profile.equipment = value;
          _next();
        },
      ),
      WorkoutFrequencyStep(
        key: ValueKey(13),
        step: 13,
        totalSteps: totalSteps,
        title: 'How often would you like to work out?',
        subtitle: 'Our recommended plan adapts to how often you train.',
        initialValue: _profile.workoutsPerWeek,
        onBack: _back,
        onContinue: (value) {
          _profile.workoutsPerWeek = value;
          _next();
        },
      ),
      WorkoutDaysStep(
        key: ValueKey(14),
        step: 14,
        totalSteps: totalSteps,
        title: 'Set your workout days',
        initialSelectedDays: _profile.workoutDays,
        initialReminderEnabled: _profile.reminderEnabled,
        onBack: _back,
        continueLabel: 'Finish',
        onContinue: _finish,
      ),
    ];

    return steps[_index];
  }
}
