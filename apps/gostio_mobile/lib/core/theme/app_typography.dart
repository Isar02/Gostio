import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

// The desktop's scale entered one step higher: what it sets in 13 is read here
// at 15, because this is held at arm's length rather than sat in front of.
abstract final class AppTypography {
  static const List<String> _fallback = <String>[AppFonts.fallbackFamily];

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static final TextTheme theme = TextTheme(
    displaySmall: _display(34, FontWeight.w700, height: 1.1, spacing: -0.8),
    headlineMedium: _display(27, FontWeight.w700, height: 1.15, spacing: -0.5),
    headlineSmall: _display(22, FontWeight.w600, height: 1.25, spacing: -0.3),
    titleLarge: _interface(19, FontWeight.w600, height: 1.3, spacing: -0.1),
    titleMedium: _interface(17, FontWeight.w600, height: 1.35),
    titleSmall: _interface(15, FontWeight.w600, height: 1.35),
    bodyLarge: _interface(16, FontWeight.w400, height: 1.5),
    bodyMedium: _interface(15, FontWeight.w400, height: 1.5),
    bodySmall: _interface(
      13,
      FontWeight.w400,
      height: 1.45,
      color: AppColors.inkMuted,
    ),
    labelLarge: _interface(15, FontWeight.w500, height: 1.2),
    labelMedium: _interface(13, FontWeight.w500, height: 1.2, spacing: 0.2),
    labelSmall: _interface(
      12,
      FontWeight.w500,
      height: 1.2,
      spacing: 0.4,
      color: AppColors.inkMuted,
    ),
  );

  static TextStyle _interface(
    double size,
    FontWeight weight, {
    double height = 1.45,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: AppFonts.interfaceFamily,
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
    fontFamily: AppFonts.displayFamily,
    fontFamilyFallback: _fallback,
    fontFeatures: _tabularFigures,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
  );
}
