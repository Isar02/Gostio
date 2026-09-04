import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reservations/data/reservation.dart';
import '../../reservations/data/reservation_standing.dart';

// The bookings most recently made, which is what the list itself is ordered by.
// The status keeps the API's own word for it and the colour it carries in the
// table, so the same booking does not read differently in two places.
class OverviewBookings extends StatelessWidget {
  const OverviewBookings({required this.bookings, super.key});

  final List<Reservation> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const EmptyState(
        title: 'Nothing booked yet',
        message: 'A booking a guest makes appears here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: bookings.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: AppSizes.hairline),
      itemBuilder: (BuildContext context, int index) =>
          _Booking(booking: bookings[index]),
    );
  }
}

class _Booking extends StatelessWidget {
  const _Booking({required this.booking});

  final Reservation booking;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  booking.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMedium,
                ),
                Text(
                  booking.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusChip(
            booking.status,
            tone: ReservationStanding.toneOf(booking.standing),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: AppSizes.numericColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppNumbers.money(booking.totalPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMedium,
                ),
                Text(AppDates.age(booking.createdAt), style: type.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
