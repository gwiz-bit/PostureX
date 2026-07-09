import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_scaffold.dart';
import 'selectable_chip.dart';

/// Final onboarding step: pick workout days and toggle reminders.
class WorkoutDaysStep extends StatefulWidget {
  const WorkoutDaysStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.initialSelectedDays,
    required this.initialReminderEnabled,
    required this.onContinue,
    this.subtitle,
    this.onBack,
    this.continueLabel = 'Continue',
  });

  static const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Set<String> initialSelectedDays;
  final bool initialReminderEnabled;
  final VoidCallback? onBack;
  final String continueLabel;
  final void Function(Set<String> days, bool reminderEnabled) onContinue;

  @override
  State<WorkoutDaysStep> createState() => _WorkoutDaysStepState();
}

class _WorkoutDaysStepState extends State<WorkoutDaysStep> {
  late final Set<String> _selectedDays = {...widget.initialSelectedDays};
  late bool _reminderEnabled = widget.initialReminderEnabled;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      continueLabel: widget.continueLabel,
      onContinue: () => widget.onContinue(_selectedDays, _reminderEnabled),
      body: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final day in WorkoutDaysStep.days)
                SizedBox(
                  width: 92,
                  child: SelectableChip(
                    label: day,
                    selected: _selectedDays.contains(day),
                    onTap: () => setState(() {
                      if (_selectedDays.contains(day)) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminder',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Helps to achieve a goal',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _reminderEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) => setState(() => _reminderEnabled = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
