import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final ThemeData light = _light();

  static ThemeData _light() {
    final TextTheme text = AppTypography.theme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.porcelain,
      canvasColor: AppColors.surface,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.compact,
      iconTheme: const IconThemeData(
        color: AppColors.inkMuted,
        size: AppSizes.icon,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: AppSizes.hairline,
        space: AppSizes.hairline,
      ),
      inputDecorationTheme: _inputs(text),
      filledButtonTheme: FilledButtonThemeData(style: _filledButton(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButton(text),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButton(text)),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.large),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.large,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadii.small,
        ),
        textStyle: text.labelMedium?.copyWith(color: AppColors.surface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(AppSpacing.sm),
        radius: AppRadii.smallRadius,
        thumbColor: WidgetStatePropertyAll<Color>(
          AppColors.inkFaint.withValues(alpha: 0.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.indigo,
        linearMinHeight: AppSizes.stroke,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.indigo,
        selectionColor: AppColors.indigo.withValues(alpha: 0.18),
        selectionHandleColor: AppColors.indigo,
      ),
    );
  }

  static const ColorScheme _scheme = ColorScheme.light(
    primary: AppColors.indigo,
    onPrimary: AppColors.surface,
    primaryContainer: AppColors.selected,
    onPrimaryContainer: AppColors.indigoDeep,
    secondary: AppColors.iris,
    onSecondary: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    error: AppColors.danger,
    onError: AppColors.surface,
    errorContainer: AppColors.dangerGround,
    onErrorContainer: AppColors.danger,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
  );

  static InputDecorationTheme _inputs(TextTheme text) {
    OutlineInputBorder edge(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadii.medium,
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
      labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      floatingLabelStyle: text.labelMedium?.copyWith(color: AppColors.indigo),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      errorMaxLines: 3,
      border: edge(AppColors.borderStrong, AppSizes.hairline),
      enabledBorder: edge(AppColors.borderStrong, AppSizes.hairline),
      focusedBorder: edge(AppColors.indigo, AppSizes.focusRing),
      errorBorder: edge(AppColors.danger, AppSizes.hairline),
      focusedErrorBorder: edge(AppColors.danger, AppSizes.focusRing),
      disabledBorder: edge(AppColors.border, AppSizes.hairline),
    );
  }

  static ButtonStyle _filledButton(TextTheme text) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.border;
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return AppColors.indigoDeep;
      }
      return AppColors.indigo;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.surface,
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, AppSizes.control)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );

  static ButtonStyle _outlinedButton(TextTheme text) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.hovered)
          ? AppColors.hover
          : AppColors.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.ink,
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, AppSizes.control)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    ),
    side: const WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: AppColors.borderStrong),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );

  static ButtonStyle _textButton(TextTheme text) => ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.indigo,
    ),
    overlayColor: const WidgetStatePropertyAll<Color>(AppColors.selected),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, AppSizes.control)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );
}
