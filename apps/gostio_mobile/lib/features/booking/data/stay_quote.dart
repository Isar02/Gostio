import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/date_range.dart';

// What a stay would cost, added up out of the figures the server answered for
// the nights it covers. The client names no price of its own: every figure
// here came off the calendar or off the listing, and the server prices the
// booking again when it is made.
@immutable
class StayQuote {
  const StayQuote._({
    required this.dates,
    required this.nightsTotal,
    required this.cleaningFee,
  });

  // Nothing at all where a night in the range has no price yet. A total made
  // out of the nights the client happens to hold is not the one that will be
  // charged, and a screen is better off offering none.
  static StayQuote? of(
    DateRange dates, {
    required double? Function(DateTime night) priceOf,
    required double cleaningFee,
  }) {
    double nights = 0;

    for (
      DateTime night = dates.from;
      night.isBefore(dates.to);
      night = CalendarDays.addDays(night, 1)
    ) {
      final double? price = priceOf(night);
      if (price == null) {
        return null;
      }

      nights += price;
    }

    return StayQuote._(
      dates: dates,
      nightsTotal: nights,
      cleaningFee: cleaningFee,
    );
  }

  final DateRange dates;

  // The nights alone, before the fee that is charged once over the booking.
  final double nightsTotal;
  final double cleaningFee;

  int get nights => dates.nights;

  double get total => nightsTotal + cleaningFee;
}
