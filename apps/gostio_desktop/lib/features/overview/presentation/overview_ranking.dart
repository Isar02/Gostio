import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/destination_share.dart';

// Where the platform's trade happened, each city against the one above it. The
// bar is read beside the figure rather than instead of it: a length says which
// is larger and the amount says by how much.
class OverviewRanking extends StatelessWidget {
  const OverviewRanking({required this.destinations, super.key});

  final List<DestinationShare> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const EmptyState(
        title: 'Nowhere yet',
        message: 'A city guests actually booked appears here.',
      );
    }

    final double peak = destinations.first.grossCharged;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final DestinationShare share in destinations)
            _Place(share: share, peak: peak),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({required this.share, required this.peak});

  final DestinationShare share;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: AppSizes.rankingCity,
            child: Text(
              share.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyMedium,
            ),
          ),
          Expanded(
            child: Tooltip(
              message:
                  '${share.bookings} '
                  '${share.bookings == 1 ? 'booking' : 'bookings'}',
              child: SizedBox(
                height: AppSizes.rankingBar,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  heightFactor: 1,
                  widthFactor: peak <= 0
                      ? 0
                      : (share.grossCharged / peak).clamp(0, 1),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.iris,
                      borderRadius: AppRadii.small,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: AppSizes.numericColumn,
            child: Text(
              AppNumbers.money(share.grossCharged),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
