import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded icon badge with a muted accent background, used for exercise
/// icons, quick-start cards and suggested routines.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    this.icon,
    this.customIcon,
    this.size = 44,
    this.iconSize = 22,
  }) : assert(icon != null || customIcon != null, 'Provide icon or customIcon');

  final IconData? icon;
  final Widget? customIcon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: customIcon ?? Icon(icon, color: AppColors.primary, size: iconSize),
    );
  }
}
