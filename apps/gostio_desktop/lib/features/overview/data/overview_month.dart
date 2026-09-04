import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A month across every listing a host owns: one row to a listing, one column
// to a day, and each stay laid over the days it takes up. The listing calendar
// draws one listing over six weeks; this draws every listing over one month,
// which is the same month read the other way round.
@immutable
class OverviewMonth {
  const OverviewMonth._({
    required this.month,
    required this.days,
    required this.rows,
    required this.arrivals,
    required this.departures,
  });

  factory OverviewMonth.of({
    required DateTime month,
    required List<LookupItem> listings,
    required List<Reservation> bookings,
    required DateTime today,
  }) {
    final DateTime first = CalendarDays.firstOfMonth(month);
    final DateTime last = CalendarDays.addDays(
      CalendarDays.addMonths(first, 1),
      -1,
    );

    // A cancelled booking holds nothing, so the days it named are free again.
    // Every other standing is drawn, a stay already finished included: the
    // month is what happened as much as what is coming.
    final List<Reservation> drawn = bookings
        .where(
          (Reservation booking) =>
              booking.standing != ReservationStatus.cancelled,
        )
        .toList(growable: false);

    return OverviewMonth._(
      month: first,
      days: <DateTime>[
        for (int day = 0; day <= CalendarDays.daysBetween(first, last); day++)
          CalendarDays.addDays(first, day),
      ],
      rows: <OverviewRow>[
        for (final LookupItem listing in listings)
          OverviewRow(
            listing: listing,
            spans: _spansOver(listing.id, drawn, first: first, last: last),
          ),
      ],
      arrivals: _movements(
        drawn,
        first: first,
        last: last,
        today: today,
        arriving: true,
      ),
      departures: _movements(
        drawn,
        first: first,
        last: last,
        today: today,
        arriving: false,
      ),
    );
  }

  final DateTime month;
  final List<DateTime> days;
  final List<OverviewRow> rows;
  final List<OverviewMovement> arrivals;
  final List<OverviewMovement> departures;

  bool get hasNoListings => rows.isEmpty;

  bool get isQuiet => rows.every((OverviewRow row) => row.spans.isEmpty);

  int get bookedNights =>
      rows.fold(0, (int total, OverviewRow row) => total + row.bookedNights);

  // A term is attended rather than stayed in: it carries a slot instead of two
  // dates, so nothing places one on a row and the window that brought it back
  // is simply wider than what is drawn.
  static List<OverviewSpan> _spansOver(
    int listingId,
    List<Reservation> bookings, {
    required DateTime first,
    required DateTime last,
  }) {
    final List<OverviewSpan> spans = <OverviewSpan>[];

    for (final Reservation booking in bookings) {
      if (booking.accommodationId != listingId) {
        continue;
      }

      if (booking.stay case (final DateTime arrival, final DateTime leaving)) {
        // A stay takes the nights between its two dates, so the day it ends on
        // belongs to the next guest and is not one of the days it covers.
        final DateTime lastNight = CalendarDays.addDays(leaving, -1);
        final DateTime from = arrival.isBefore(first) ? first : arrival;
        final DateTime to = lastNight.isAfter(last) ? last : lastNight;

        if (to.isBefore(from)) {
          continue;
        }

        spans.add(
          OverviewSpan(
            booking: booking,
            column: CalendarDays.daysBetween(first, from),
            span: CalendarDays.daysBetween(from, to) + 1,
            startsHere: !arrival.isBefore(first),
            endsHere: !lastNight.isAfter(last),
          ),
        );
      }
    }

    // One listing holds one stay at a time, so a row is a single lane and the
    // spans on it are read left to right.
    return spans
      ..sort((OverviewSpan a, OverviewSpan b) => a.column.compareTo(b.column));
  }

  static List<OverviewMovement> _movements(
    List<Reservation> bookings, {
    required DateTime first,
    required DateTime last,
    required DateTime today,
    required bool arriving,
  }) {
    final List<OverviewMovement> movements = <OverviewMovement>[];

    for (final Reservation booking in bookings) {
      if (booking.stay case (final DateTime arrival, final DateTime leaving)) {
        final DateTime day = arriving ? arrival : leaving;

        if (day.isBefore(first) || day.isAfter(last)) {
          continue;
        }

        movements.add(
          OverviewMovement(
            booking: booking,
            day: day,
            daysAhead: CalendarDays.daysBetween(today, day),
          ),
        );
      }
    }

    return movements..sort(
      (OverviewMovement a, OverviewMovement b) => a.day.compareTo(b.day),
    );
  }
}

@immutable
class OverviewRow {
  const OverviewRow({required this.listing, required this.spans});

  final LookupItem listing;
  final List<OverviewSpan> spans;

  int get bookedNights =>
      spans.fold(0, (int total, OverviewSpan span) => total + span.span);
}

// A stay clipped to the month it is drawn in. One reaching past either edge is
// drawn open there, so a block that stops at the edge is not read as a stay
// that ends on it.
@immutable
class OverviewSpan {
  const OverviewSpan({
    required this.booking,
    required this.column,
    required this.span,
    required this.startsHere,
    required this.endsHere,
  });

  final Reservation booking;
  final int column;
  final int span;
  final bool startsHere;
  final bool endsHere;
}

@immutable
class OverviewMovement {
  const OverviewMovement({
    required this.booking,
    required this.day,
    required this.daysAhead,
  });

  final Reservation booking;
  final DateTime day;

  // Days from today, negative where it has already happened.
  final int daysAhead;

  bool get isPast => daysAhead < 0;
}
