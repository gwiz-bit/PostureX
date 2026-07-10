import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_scaffold.dart';

class SelectCardOption {
  const SelectCardOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}

/// Onboarding step where the user picks one descriptive card from a list
/// (fitness level, activity level).
class SingleSelectCardStep extends StatefulWidget {
  const SingleSelectCardStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.initialValue,
    required this.onContinue,
    this.subtitle,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final List<SelectCardOption> options;
  final String initialValue;
  final VoidCallback? onBack;
  final void Function(String value) onContinue;

  @override
  State<SingleSelectCardStep> createState() => _SingleSelectCardStepState();
}

class _SingleSelectCardStepState extends State<SingleSelectCardStep> {
  late String _selected = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_selected),
      body: Column(
        children: [
          for (final option in widget.options) ...[
            _CardOption(
              option: option,
              selected: _selected == option.value,
              onTap: () => setState(() => _selected = option.value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CardOption extends StatelessWidget {
  const _CardOption({required this.option, required this.selected, required this.onTap});

  final SelectCardOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              option.icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
