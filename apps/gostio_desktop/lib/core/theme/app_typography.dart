import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const String interfaceFamily = 'Geist';
  static const String displayFamily = 'PlusJakartaSans';
  static const String fallbackFamily = 'Manrope';

  static const List<String> _fallback = <String>[fallbackFamily];

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static final TextTheme theme = TextTheme(
    displaySmall: _display(30, FontWeight.w700, height: 1.15, spacing: -0.6),
    headlineMedium: _display(24, FontWeight.w700, height: 1.2, spacing: -0.4),
    headlineSmall: _display(20, FontWeight.w600, height: 1.25, spacing: -0.2),
    titleLarge: _interface(17, FontWeight.w600, height: 1.3, spacing: -0.1),
    titleMedium: _interface(15, FontWeight.w600, height: 1.35),
    titleSmall: _interface(13, FontWeight.w600, height: 1.35),
    bodyLarge: _interface(14, FontWeight.w400, height: 1.45),
    bodyMedium: _interface(13, FontWeight.w400, height: 1.45),
    bodySmall: _interface(
      12,
      FontWeight.w400,
      height: 1.4,
      color: AppColors.inkMuted,
    ),
    labelLarge: _interface(13, FontWeight.w500, height: 1.2),
    labelMedium: _interface(12, FontWeight.w500, height: 1.2, spacing: 0.2),
    labelSmall: _interface(
      11,
      FontWeight.w500,
      height: 1.2,
      spacing: 0.4,
      color: AppColors.inkMuted,
    ),
  );

  static TextStyle _interface(
    double size,
    FontWeight weight, {
    double height = 1.4,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: interfaceFamily,
    fontFamilyFallback: _fallback,
    fontFeatures: _tabularFigures,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
  );

  static TextStyle _display(
    double size,
    FontWeight weight, {
    double height = 1.2,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: _fallback,
    fontFeatures: _tabularFigures,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
  );
}
