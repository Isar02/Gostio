import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/overview_month.dart';

// Who arrives and who leaves inside the month on screen. The day is read
// against today rather than printed as a date the reader has to subtract, and
// one already behind is dimmed rather than dropped: the month is what happened
// as much as what is coming.
class OverviewMovements extends StatelessWidget {
  const OverviewMovements({
    required this.movements,
    required this.quiet,
    super.key,
  });

  final List<OverviewMovement> movements;
  final String quiet;

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return EmptyState(title: 'Nothing to see off', message: quiet);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: movements.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: AppSizes.hairline),
      itemBuilder: (BuildContext context, int index) =>
          _Movement(movement: movements[index]),
    );
  }
}

class _Movement extends StatelessWidget {
  const _Movement({required this.movement});

  final OverviewMovement movement;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;
    final Color ink = movement.isPast ? AppColors.inkFaint : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  movement.booking.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMedium?.copyWith(color: ink),
                ),
                Text(
                  movement.booking.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            _when,
            style: type.labelMedium?.copyWith(
              color: movement.daysAhead == 0 ? AppColors.indigo : ink,
            ),
          ),
        ],
      ),
    );
  }

  String get _when => switch (movement.daysAhead) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => AppDates.day(movement.day),
  };
}
