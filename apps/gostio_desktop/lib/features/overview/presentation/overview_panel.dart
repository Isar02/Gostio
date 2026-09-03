import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';

// The one container the overview is built out of. Every panel on either screen
// is this: a heading, whatever the heading is about, and nothing else drawn
// around it.
class OverviewPanel extends StatelessWidget {
  const OverviewPanel({
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: type.titleMedium),
                      if (caption case final String caption)
                        Text(caption, style: type.bodySmall),
                    ],
                  ),
                ),
                if (trailing case final Widget trailing) trailing,
              ],
            ),
          ),
          const Divider(height: AppSizes.hairline),
          // The panel is as tall as what it holds, and what it holds carries
          // its own height: every overview is a column that scrolls as a whole
          // rather than a screenful of panels each scrolling inside itself.
          child,
        ],
      ),
    );
  }
}
