import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A card carries a hairline rather than a shadow. Twenty of these scroll past
// on a phone, and twenty shadows read as noise rather than as depth.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.isSelected = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool isSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget surface = Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.large,
        side: BorderSide(
          color: isSelected ? AppColors.indigo : AppColors.border,
          width: isSelected ? AppSizes.focusRing : AppSizes.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.selected,
        highlightColor: AppColors.hover,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (semanticLabel == null) {
      return surface;
    }

    // A card is one thing on the screen and is worth hearing as one. Where a
    // caller has written that sentence, the pieces it was written from stop
    // announcing themselves separately.
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: surface,
    );
  }
}
