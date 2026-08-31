import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import 'workspace.dart';
import 'workspace_mode.dart';

// Switching changes which authorised view the client asks for. It never
// changes the claims on the token or what the caller is allowed to do.
class WorkspaceSwitch extends StatelessWidget {
  const WorkspaceSwitch({required this.workspace, super.key});

  final Workspace workspace;

  static const double _inset = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.control,
      padding: const EdgeInsets.all(_inset),
      decoration: const BoxDecoration(
        color: AppColors.porcelain,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final WorkspaceMode mode in workspace.modes)
            _Segment(
              mode: mode,
              isSelected: mode == workspace.mode,
              onSelected: () => workspace.switchTo(mode),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.mode,
    required this.isSelected,
    required this.onSelected,
  });

  final WorkspaceMode mode;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Work as ${mode.label.toLowerCase()}',
      child: InkWell(
        onTap: isSelected ? null : onSelected,
        borderRadius: AppRadii.pill,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : null,
            borderRadius: AppRadii.pill,
          ),
          child: Text(
            mode.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? AppColors.ink : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
