import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

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
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.surface,
      iconTheme: const IconThemeData(
        color: AppColors.inkMuted,
        size: AppSizes.icon,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppSizes.appBar,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        iconTheme: const IconThemeData(
          color: AppColors.ink,
          size: AppSizes.icon,
        ),
      ),
      navigationBarTheme: _navigationBar(text),
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
      segmentedButtonTheme: SegmentedButtonThemeData(style: _segmented(text)),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
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

  // The bar the client is moved through. The chosen tab is said twice, in the
  // ground behind its icon and in the weight of its label, because a colour
  // alone is not read by everyone who reads the bar.
  static NavigationBarThemeData _navigationBar(TextTheme text) {
    return NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.selected,
      elevation: 0,
      height: AppSizes.navigationBar,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadii.pill),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (Set<WidgetState> states) => IconThemeData(
          size: AppSizes.icon,
          color: states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? text.labelSmall?.copyWith(
                color: AppColors.indigo,
                fontWeight: FontWeight.w600,
              )
            : text.labelSmall?.copyWith(color: AppColors.inkMuted),
      ),
    );
  }

  // A field carries its own ground rather than a box drawn on the page: the
  // border is what a thumb aims at, and the fill is what it reads as empty.
  static InputDecorationTheme _inputs(TextTheme text) {
    OutlineInputBorder edge(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadii.medium,
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.hover,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
      labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      floatingLabelStyle: text.labelMedium?.copyWith(color: AppColors.indigo),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      errorMaxLines: 3,
      border: edge(AppColors.border, AppSizes.hairline),
      enabledBorder: edge(AppColors.border, AppSizes.hairline),
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
      return states.contains(WidgetState.pressed)
          ? AppColors.indigoDeep
          : AppColors.indigo;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.surface,
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(AppSizes.touchTarget),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );

  static ButtonStyle _outlinedButton(TextTheme text) => ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll<Color>(AppColors.surface),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.ink,
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(AppSizes.touchTarget),
    ),
    side: const WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: AppColors.borderStrong),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );

  // The toggle between two catalogues, which is a switch rather than a pair of
  // buttons: the chosen half carries the ground so that what is being read is
  // said in the same weight the tab bar says it in. Its corners match the field
  // above it, because the two are one block of header rather than two controls.
  static ButtonStyle _segmented(TextTheme text) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.selected)
          ? AppColors.indigo
          : AppColors.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.selected)
          ? AppColors.surface
          : AppColors.ink,
    ),
    overlayColor: const WidgetStatePropertyAll<Color>(AppColors.selected),
    textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(AppSizes.touchTarget),
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
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size(0, AppSizes.touchTarget),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
  );
}
