import 'package:flutter/material.dart';

import 'onboarding_scaffold.dart';
import 'selectable_chip.dart';

/// Onboarding step where the user picks any number of chips from a list
/// (goals, focus areas).
class MultiSelectChipStep extends StatefulWidget {
  const MultiSelectChipStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.onContinue,
    this.subtitle,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> initialSelected;
  final VoidCallback? onBack;
  final void Function(Set<String> selected) onContinue;

  @override
  State<MultiSelectChipStep> createState() => _MultiSelectChipStepState();
}

class _MultiSelectChipStepState extends State<MultiSelectChipStep> {
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_selected),
      body: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in widget.options)
            SelectableChip(
              label: option,
              selected: _selected.contains(option),
              onTap: () => setState(() {
                if (_selected.contains(option)) {
                  _selected.remove(option);
                } else {
                  _selected.add(option);
                }
              }),
            ),
        ],
      ),
    );
  }
}
