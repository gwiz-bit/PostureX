import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step where the user checks any number of items, with an
/// optional exclusive "None of the above" option (health issues, equipment).
class CheckboxListStep extends StatefulWidget {
  const CheckboxListStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.onContinue,
    this.subtitle,
    this.onBack,
    this.noneOfTheAboveLabel = 'None of the above',
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> initialSelected;
  final VoidCallback? onBack;
  final void Function(Set<String> selected) onContinue;
  final String noneOfTheAboveLabel;

  @override
  State<CheckboxListStep> createState() => _CheckboxListStepState();
}

class _CheckboxListStepState extends State<CheckboxListStep> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _toggle(String option) {
    setState(() {
      if (option == widget.noneOfTheAboveLabel) {
        _selected
          ..clear()
          ..add(option);
        return;
      }
      _selected.remove(widget.noneOfTheAboveLabel);
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allOptions = [...widget.options, widget.noneOfTheAboveLabel];
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_selected),
      body: Column(
        children: [
          for (final option in allOptions) ...[
            _CheckRow(
              label: option,
              checked: _selected.contains(option),
              onTap: () => _toggle(option),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: checked ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: checked ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: checked ? AppColors.primary : AppColors.textTertiary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
