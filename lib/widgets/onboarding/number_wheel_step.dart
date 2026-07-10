import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../info_tip_card.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step for picking a bounded integer value with a big live
/// readout and a scroll wheel — used for height, age and weight.
class NumberWheelStep extends StatefulWidget {
  const NumberWheelStep({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.unit,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onContinue,
    this.subtitle,
    this.onBack,
    this.tipEmoji,
    this.tipTitle,
    this.tipBody,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final String unit;
  final int min;
  final int max;
  final int initialValue;
  final VoidCallback? onBack;
  final void Function(int value) onContinue;
  final String? tipEmoji;
  final String? tipTitle;
  final String? tipBody;

  @override
  State<NumberWheelStep> createState() => _NumberWheelStepState();
}

class _NumberWheelStepState extends State<NumberWheelStep> {
  late int _value = widget.initialValue;
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialValue - widget.min);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(int value) => widget.unit.isEmpty ? '$value' : '$value ${widget.unit}';

  @override
  Widget build(BuildContext context) {
    final count = widget.max - widget.min + 1;
    return OnboardingScaffold(
      step: widget.step,
      totalSteps: widget.totalSteps,
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_value),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.tipTitle != null) ...[
            InfoTipCard(
              emoji: widget.tipEmoji ?? '💡',
              title: widget.tipTitle!,
              body: widget.tipBody ?? '',
            ),
            const SizedBox(height: 32),
          ],
          Text(
            _format(_value),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 44,
              backgroundColor: Colors.transparent,
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onSelectedItemChanged: (index) => setState(() => _value = widget.min + index),
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(
                      _format(widget.min + i),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
