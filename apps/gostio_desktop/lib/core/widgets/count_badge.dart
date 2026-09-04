import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  static const int _largest = 99;

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      height: AppSizes.badge,
      constraints: const BoxConstraints(minWidth: AppSizes.badge),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        count > _largest ? '$_largest+' : '$count',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.surface),
      ),
    );
  }
}
