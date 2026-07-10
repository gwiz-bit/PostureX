import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step for choosing a weekly workout frequency via slider.
class WorkoutFrequencyStep extends StatefulWidget {
  const WorkoutFrequencyStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.initialValue,
    required this.onContinue,
    this.subtitle,
    this.onBack,
    this.min = 1,
    this.max = 7,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final int initialValue;
  final int min;
  final int max;
  final VoidCallback? onBack;
  final void Function(int value) onContinue;

  @override
  State<WorkoutFrequencyStep> createState() => _WorkoutFrequencyStepState();
}

class _WorkoutFrequencyStepState extends State<WorkoutFrequencyStep> {
  late double _value = widget.initialValue.toDouble();

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_value.round()),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            '${_value.round()}x',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 56,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_value.round()} workouts a week',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 32),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.track,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _value,
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              onChanged: (value) => setState(() => _value = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Less', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Text('More', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
