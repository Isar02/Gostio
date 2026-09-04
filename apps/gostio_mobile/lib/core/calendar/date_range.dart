import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// The dates a reader chose, held the way the API reads them: a stay occupies
// the nights from the first up to but not including the last, so 12 to 15 June
// is three nights and the fifteenth is free for somebody else.
//
// A range that runs backwards or holds no night is refused rather than
// asserted against: an assertion is compiled out of the build the reader
// actually runs, and every caller of `nights` would be left to check.
@immutable
class DateRange {
  factory DateRange({required DateTime from, required DateTime to}) {
    final DateTime first = CalendarDays.of(from);
    final DateTime last = CalendarDays.of(to);

    if (!first.isBefore(last)) {
      throw ArgumentError.value(
        to,
        'to',
        'A stay runs forwards and holds at least one night, so it must end '
            'after ${CalendarDays.write(first)}',
      );
    }

    return DateRange._(first, last);
  }

  const DateRange._(this.from, this.to);

  // Both ends are calendar days rather than moments. A date carrying a time
  // would compare and equal by the hour it was built at, and two readers who
  // chose the same nights would hold different stays.
  final DateTime from;
  final DateTime to;

  int get nights => CalendarDays.daysBetween(from, to);

  // The nights this range holds, which is every day it covers except the one
  // it ends on.
  bool holdsNight(DateTime day) {
    final DateTime night = CalendarDays.of(day);

    return !night.isBefore(from) && night.isBefore(to);
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() =>
      'DateRange(${CalendarDays.write(from)} to ${CalendarDays.write(to)})';
}
