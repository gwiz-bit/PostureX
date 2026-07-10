import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Status / badge colors — semantic, kept from admin design
const Color kGreen = Color(0xFF3B6D11);
const Color kGreenBg = Color(0xFFEAF3DE);
const Color kRed = Color(0xFFA32D2D);
const Color kRedBg = Color(0xFFFCEBEB);
const Color kBlue = Color(0xFF185FA5);
const Color kBlueBg = Color(0xFFE6F1FB);
const Color kAmber = Color(0xFFBA7517);
const Color kAmberBg = Color(0xFFFAEEDA);
const Color kPurple = Color(0xFF534AB7);
const Color kPurpleBg = Color(0xFFEEEDFE);
const Color kGrayFg = Color(0xFF5F5E5A);
const Color kGrayBg = Color(0xFFF1EFE8);
// Coral maps to the main app's primary accent (coral orange)
const Color kCoral = AppColors.primary;
const Color kCoralBg = AppColors.primaryMuted;

// Layout / text aliases — adapted to dark PostureX palette
const Color kNavy = AppColors.primary;        // CTA / active accent (coral)
const Color kInk = AppColors.textPrimary;
const Color kMuted = AppColors.textSecondary;
const Color kSubtitle = AppColors.textTertiary;
const Color kBorder = AppColors.border;
const Color kDivider = AppColors.border;

// Input decoration styled for dark theme
InputDecoration adminInput(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
