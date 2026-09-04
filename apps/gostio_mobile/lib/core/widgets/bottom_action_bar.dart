import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// The bar a screen commits from. What is being agreed to stays beside the
// button rather than scrolling away above it, because the figure and the act
// are one decision.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    required this.action,
    this.label,
    this.detail,
    this.secondary,
    super.key,
  });

  final Widget action;
  final String? label;
  final String? detail;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              if (label case final String label)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(label, style: text.titleMedium),
                      if (detail case final String detail)
                        Text(
                          detail,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              if (secondary case final Widget secondary) ...<Widget>[
                secondary,
                const SizedBox(width: AppSpacing.md),
              ],
              // The action is given a share of the bar rather than its own
              // width. A filled button is themed to fill what it is offered,
              // and a row offers a child that does not flex no width at all.
              // With nothing named beside it that share is the whole bar: a
              // half-width primary action reads as the lesser of two.
              Expanded(flex: label == null ? 1 : 2, child: action),
            ],
          ),
        ),
      ),
    );
  }
}
