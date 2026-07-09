import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF101010);
  static const surface = Color(0xFF1C1C1A);
  static const surfaceAlt = Color(0xFF161615);
  static const border = Color(0xFF2C2C2A);
  static const textPrimary = Color(0xFFF5F3EE);
  static const textSecondary = Color(0xFF8A8A86);
  static const textMuted = Color(0xFF5F5E5A);

  static const teal = Color(0xFF5DCAA5);
  static const tealDark = Color(0xFF04342C);
  static const tealLight = Color(0xFF9FE1CB);

  static const coral = Color(0xFFD85A30);
  static const coralDark = Color(0xFF4A1B0C);
  static const coralLight = Color(0xFFF0997B);

  static const amber = Color(0xFFEF9F27);
  static const amberDark = Color(0xFF412402);
  static const amberLight = Color(0xFFFAC775);

  static const red = Color(0xFFE24B4A);
  static const gray = Color(0xFFB4B2A9);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        surface: AppColors.surface,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
    );
  }
}
