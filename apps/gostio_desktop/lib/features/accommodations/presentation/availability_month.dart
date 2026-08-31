import 'package:flutter/foundation.dart';

import '../../../core/time/calendar_days.dart';
import '../../reservations/data/reservation.dart';
import '../../reservations/data/reservation_status.dart';
import '../data/accommodation_availability.dart';

// One month as the calendar draws it: the six weeks that hold it, what each
// day carries, and the bookings laid over them. The grid is always six weeks
// so that a month beginning on a Sunday does not make the calendar taller than
// the one before it.
@immutable
class AvailabilityMonth {
  const AvailabilityMonth._({required this.month, required this.weeks});

  factory AvailabilityMonth.of({
    required DateTime month,
    required List<AccommodationAvailability> entries,
    required List<Reservation> bookings,
    required DateTime today,
  }) {
    // A cancelled booking holds nothing, so the days it named are free again.
    // Every other status is drawn, a stay that has already finished included:
    // the calendar is what happened here as much as what is coming.
    final List<Reservation> drawn = bookings
        .where(
          (Reservation booking) =>
              booking.standing != ReservationStatus.cancelled,
        )
        .toList(growable: false);

    final DateTime start = startOfGrid(month);
    final List<AvailabilityWeek> weeks = <AvailabilityWeek>[];

    for (int week = 0; week < _weeks; week++) {
      final List<AvailabilityDay> days = <AvailabilityDay>[
        for (int weekday = 0; weekday < DateTime.daysPerWeek; weekday++)
          _dayAt(
            CalendarDays.addDays(start, week * DateTime.daysPerWeek + weekday),
            month: month,
            entries: entries,
            bookings: drawn,
            today: today,
          ),
      ];

      weeks.add(AvailabilityWeek(days: days, bars: _barsAcross(days)));
    }

    return AvailabilityMonth._(month: month, weeks: weeks);
  }

  static const int _weeks = 6;

  static DateTime startOfGrid(DateTime month) =>
      CalendarDays.startOfWeek(CalendarDays.firstOfMonth(month));

  static DateTime endOfGrid(DateTime month) => CalendarDays.addDays(
    startOfGrid(month),
    _weeks * DateTime.daysPerWeek - 1,
  );

  final DateTime month;
  final List<AvailabilityWeek> weeks;

  Iterable<AvailabilityDay> get days =>
      weeks.expand((AvailabilityWeek week) => week.days);

  int get blockedDays => _count((AvailabilityDay day) => day.isBlocked);

  int get repricedDays => _count((AvailabilityDay day) => day.isRepriced);

  int get bookedNights => _count((AvailabilityDay day) => day.booking != null);

  int _count(bool Function(AvailabilityDay day) counts) =>
      days.where((AvailabilityDay day) => day.isInMonth && counts(day)).length;

  bool hasAnEntryBetween({required DateTime from, required DateTime to}) =>
      _between(from, to).any((AvailabilityDay day) => day.entry != null);

  int bookedNightsBetween({required DateTime from, required DateTime to}) =>
      _between(
        from,
        to,
      ).where((AvailabilityDay day) => day.booking != null).length;

  Iterable<AvailabilityDay> _between(DateTime from, DateTime to) => days.where(
    (AvailabilityDay day) => !day.date.isBefore(from) && !day.date.isAfter(to),
  );

  static AvailabilityDay _dayAt(
    DateTime date, {
    required DateTime month,
    required List<AccommodationAvailability> entries,
    required List<Reservation> bookings,
    required DateTime today,
  }) {
    AccommodationAvailability? entry;
    for (final AccommodationAvailability candidate in entries) {
      if (candidate.covers(date)) {
        entry = candidate;
        break;
      }
    }

    Reservation? booking;
    for (final Reservation candidate in bookings) {
      if (candidate.occupies(date)) {
        booking = candidate;
        break;
      }
    }

    return AvailabilityDay(
      date: date,
      isInMonth: date.year == month.year && date.month == month.month,
      isToday: date == today,
      entry: entry,
      booking: booking,
    );
  }

  // A stay is one bar across the nights it holds rather than a mark on each of
  // them, so the days it covers in this week are gathered into a run. A stay
  // crossing a Sunday is drawn twice, open at the edge it continues over.
  static List<BookingBar> _barsAcross(List<AvailabilityDay> days) {
    final List<BookingBar> bars = <BookingBar>[];

    int column = 0;
    while (column < days.length) {
      final Reservation? booking = days[column].booking;
      if (booking == null) {
        column++;
        continue;
      }

      int span = 1;
      while (column + span < days.length &&
          days[column + span].booking?.id == booking.id) {
        span++;
      }

      bars.add(
        BookingBar(
          booking: booking,
          column: column,
          span: span,
          startsHere: !booking.occupies(
            CalendarDays.addDays(days[column].date, -1),
          ),
          endsHere: !booking.occupies(
            CalendarDays.addDays(days[column + span - 1].date, 1),
          ),
        ),
      );

      column += span;
    }

    return bars;
  }
}

@immutable
class AvailabilityWeek {
  const AvailabilityWeek({required this.days, required this.bars});

  final List<AvailabilityDay> days;
  final List<BookingBar> bars;
}

@immutable
class AvailabilityDay {
  const AvailabilityDay({
    required this.date,
    required this.isInMonth,
    required this.isToday,
    required this.entry,
    required this.booking,
  });

  final DateTime date;
  final bool isInMonth;
  final bool isToday;
  final AccommodationAvailability? entry;
  final Reservation? booking;

  bool get isBlocked => entry != null && !entry!.isAvailable;

  bool get isRepriced => entry != null && entry!.isAvailable;

  double? get priceOverride => entry?.priceOverride;
}

@immutable
class BookingBar {
  const BookingBar({
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
