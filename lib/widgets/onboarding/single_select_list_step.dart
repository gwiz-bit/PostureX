import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_scaffold.dart';

class SingleSelectOption {
  const SingleSelectOption({required this.value, required this.label, this.trailing});

  final String value;
  final String label;
  final Widget? trailing;
}

/// Onboarding step where the user picks exactly one row from a vertical
/// list (gender, motivation).
class SingleSelectListStep extends StatefulWidget {
  const SingleSelectListStep({
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
  final List<SingleSelectOption> options;
  final String initialValue;
  final VoidCallback? onBack;
  final void Function(String value) onContinue;

  @override
  State<SingleSelectListStep> createState() => _SingleSelectListStepState();
}

class _SingleSelectListStepState extends State<SingleSelectListStep> {
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
            _OptionRow(
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

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected, required this.onTap});

  final SingleSelectOption option;
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
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (option.trailing != null) ...[
              const SizedBox(width: 12),
              option.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
