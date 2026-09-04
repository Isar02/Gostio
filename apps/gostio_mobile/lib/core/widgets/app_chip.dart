import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A filter the reader can put on and take off. It is the same pill whether it
// sits in a sheet being chosen or under the search field being dismissed, so
// the two never drift apart.
//
// One pill is one control: a cross drawn inside a chip is smaller than a
// thumb, so the whole chip answers the gesture the cross announces. Which
// gesture that is comes from which constructor was used, so a chip that shows
// a cross and runs something else cannot be written — in any build.
class AppChip extends StatelessWidget {
  const AppChip(
    this.label, {
    this.isSelected = false,
    this.onTap,
    this.icon,
    super.key,
  }) : onRemove = null;

  // A filter already in force, drawn under the field it was applied to.
  const AppChip.removable(
    this.label, {
    required VoidCallback this.onRemove,
    this.icon,
    super.key,
  }) : isSelected = false,
       onTap = null;

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final IconData? icon;

  bool get _isRemovable => onRemove != null;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground = isSelected ? AppColors.indigo : AppColors.ink;
    final VoidCallback? gesture = onTap ?? onRemove;

    return Semantics(
      container: true,
      button: gesture != null,
      selected: isSelected,
      label: _isRemovable ? 'Remove $label' : label,
      onTap: gesture,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? AppColors.selected : AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.pill,
          side: BorderSide(
            color: isSelected ? AppColors.indigo : AppColors.border,
            width: isSelected ? AppSizes.focusRing : AppSizes.hairline,
          ),
        ),
        child: InkWell(
          onTap: gesture,
          splashColor: AppColors.selected,
          child: ConstrainedBox(
            // A pill is shorter than a button, but what a thumb aims at is not.
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon case final IconData icon) ...<Widget>[
                    Icon(icon, size: AppSizes.iconSmall, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: text.labelLarge?.copyWith(color: foreground),
                  ),
                  if (_isRemovable) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.close,
                      size: AppSizes.iconSmall,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
