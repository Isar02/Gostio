import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import 'standing_tone.dart';

// One booking in the list: what it is for, when it is, who is coming, and
// where it stands. A booking against a term carries no dates of its own, so
// the row says when its term begins — which the server answers beside it,
// because a list cannot read a term back one card at a time.
class TripCard extends StatelessWidget {
  const TripCard(this.booking, {this.onTap, super.key});

  final Reservation booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: _spoken,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  booking.listingTitle,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (_when case final String moment)
                  Text(
                    moment,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppNumbers.counted(booking.guestCount, 'guest'),
                  style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              StatusChip(
                booking.status,
                tone: StandingTone.of(booking.standing),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppNumbers.money(booking.totalPrice),
                style: text.titleSmall,
              ),
              if (_settlement case (final String word, final Color colour))
                Text(word, style: text.bodySmall?.copyWith(color: colour)),
            ],
          ),
        ],
      ),
    );
  }

  // A stay is the nights it takes up; a term is the hour it begins at. Neither
  // is drawn from anything this client worked out.
  String? get _when {
    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      return '${AppDates.day(arrival)} – ${AppDates.day(departure)} · '
          '${AppNumbers.counted(CalendarDays.daysBetween(arrival, departure), 'night')}';
    }

    return switch (booking.experienceSlotStartTime) {
      final DateTime begins => AppDates.dateTime(begins),
      null => null,
    };
  }

  // Whether this booking was settled, which is read off the row rather than
  // worked out from what can still be done about it. A booking that was called
  // off says nothing: it owes nothing either way, and a word about money on it
  // would read as one more thing the reader has to see to.
  (String, Color)? get _settlement {
    if (booking.isPaid) {
      return ('Paid', AppColors.inkFaint);
    }

    return booking.standing == ReservationStatus.cancelled
        ? null
        : ('Not paid', Tone.attention.foreground);
  }

  String get _spoken {
    final StringBuffer spoken = StringBuffer(booking.listingTitle);

    if (_when case final String moment) {
      spoken.write(', $moment');
    }

    spoken
      ..write(', ${AppNumbers.counted(booking.guestCount, 'guest')}')
      ..write(', ${booking.status}')
      ..write(', ${AppNumbers.money(booking.totalPrice)}');

    if (_settlement case (final String word, _)) {
      spoken.write(', $word');
    }

    return spoken.toString();
  }
}
