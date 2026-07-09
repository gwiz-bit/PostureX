import 'package:flutter/material.dart';

/// Color palette for PostureX — dark, high-contrast, energetic coral-orange
/// accent suited to a workout/fitness tracking app.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0C0D);
  static const Color surface = Color(0xFF1A1B1D);
  static const Color surfaceElevated = Color(0xFF222325);
  static const Color border = Color(0xFF2C2D30);

  static const Color primary = Color(0xFFFF6F4F);
  static const Color primaryMuted = Color(0xFF402920);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9E);
  static const Color textTertiary = Color(0xFF5C5D60);

  static const Color track = Color(0xFF2A2B2D);

  static const Color chartOrange = Color(0xFFFFA64D);
  static const Color chartBlue = Color(0xFF4DA6FF);
  static const Color chartGreen = Color(0xFF6DE86D);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.border,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }
}
