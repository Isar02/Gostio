import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import 'price_table.dart';

// What a booking is: what it is for, who is coming, when it is, and what it
// comes to. The screen that has just made one and the trip that opens it again
// draw the same thing, so what stands between the two — a hold, a payment, a
// standing — is handed in rather than decided here.
class BookingSummary extends StatelessWidget {
  const BookingSummary(this.booking, {this.term, this.standing, super.key});

  final Reservation booking;

  // The term this books, where the screen already holds it. The booking says
  // when its term begins; a term read whole also says how long it runs.
  final ExperienceSlot? term;

  final Widget? standing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(booking.listingTitle, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        for (final (String label, String value) in _facts)
          _Fact(label: label, value: value),
        if (standing case final Widget standing) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          standing,
        ],
        const SizedBox(height: AppSpacing.xl),
        PriceTable(lines: _lines, total: booking.totalPrice),
      ],
    );
  }

  List<(String, String)> get _facts {
    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      return <(String, String)>[
        ('Check in', AppDates.day(arrival)),
        ('Check out', AppDates.day(departure)),
        ('Guests', AppNumbers.counted(booking.guestCount, 'guest')),
      ];
    }

    return <(String, String)>[
      if (term?.startTime ?? booking.experienceSlotStartTime
          case final DateTime begins)
        ('Starts', AppDates.dateTime(begins)),
      if (term case final ExperienceSlot term)
        ('Lasts', AppDurations.inWords(term.durationMinutes)),
      ('Guests', AppNumbers.counted(booking.guestCount, 'guest')),
    ];
  }

  List<(String, double)> get _lines {
    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      return <(String, double)>[
        (
          AppNumbers.counted(
            CalendarDays.daysBetween(arrival, departure),
            'night',
          ),
          booking.accommodationTotal ?? booking.totalPrice,
        ),
        if (booking.cleaningFee case final double fee when fee > 0)
          ('Cleaning fee', fee),
      ];
    }

    return <(String, double)>[
      (AppNumbers.counted(booking.guestCount, 'guest'), booking.totalPrice),
    ];
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}
