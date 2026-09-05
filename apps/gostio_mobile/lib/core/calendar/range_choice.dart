import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import 'date_range.dart';

// The two taps a stay is taken with, over a month that says which nights are
// still for sale. The first opens a range and the second closes it; a second
// tap that cannot close one opens a new range rather than refusing the
// gesture, because a reader who tapped a day meant to choose it.
//
// A stay occupies the nights up to the day it ends on, so the day the reader
// leaves may already belong to somebody else while the ones before it may not.
// That rule is the whole of what is decided here, and it is decided in one
// place because a sheet and a screen both take a stay with it.
//
// What is still for sale is asked for rather than held: the sheet knows it
// when it opens and a screen learns it a month at a time.
@immutable
class RangeChoice {
  const RangeChoice({required this.firstDay, this.lastDay, this.from, this.to});

  // The window any of this is chosen inside. A day outside it is not offered
  // as either end, whatever the nights around it say.
  final DateTime firstDay;
  final DateTime? lastDay;

  final DateTime? from;
  final DateTime? to;

  DateRange? get range {
    final DateTime? from = this.from;
    final DateTime? to = this.to;

    return from == null || to == null ? null : DateRange(from: from, to: to);
  }

  RangeChoice get cleared => RangeChoice(firstDay: firstDay, lastDay: lastDay);

  // Whether the day answers a tap at all.
  bool mayTake(DateTime day, {required bool Function(DateTime night) isNight}) {
    final DateTime chosen = CalendarDays.of(day);

    return (_isWithin(chosen) && isNight(chosen)) || _closes(chosen, isNight);
  }

  RangeChoice take(
    DateTime day, {
    required bool Function(DateTime night) isNight,
  }) {
    final DateTime chosen = CalendarDays.of(day);

    return _closes(chosen, isNight)
        ? RangeChoice(
            firstDay: firstDay,
            lastDay: lastDay,
            from: from,
            to: chosen,
          )
        : RangeChoice(firstDay: firstDay, lastDay: lastDay, from: chosen);
  }

  // Whether a range chosen earlier is one this window would still take. Nights
  // are sold while a reader is elsewhere, so a range handed back in is checked
  // rather than trusted.
  bool holds(
    DateRange range, {
    required bool Function(DateTime night) isNight,
  }) =>
      _isWithin(range.from) &&
      _isWithin(range.to) &&
      !_holdsClosedNight(range.from, range.to, isNight);

  @override
  bool operator ==(Object other) =>
      other is RangeChoice &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(firstDay, lastDay, from, to);

  bool _isWithin(DateTime day) {
    final DateTime? lastDay = this.lastDay;

    return !day.isBefore(firstDay) &&
        (lastDay == null || !day.isAfter(lastDay));
  }

  bool _closes(DateTime day, bool Function(DateTime night) isNight) {
    final DateTime? from = this.from;

    return from != null &&
        to == null &&
        day.isAfter(from) &&
        _isWithin(day) &&
        !_holdsClosedNight(from, day, isNight);
  }

  // Every night the range would cover, which is every day it holds except the
  // one it ends on.
  bool _holdsClosedNight(
    DateTime from,
    DateTime to,
    bool Function(DateTime night) isNight,
  ) {
    for (
      DateTime night = from;
      night.isBefore(to);
      night = CalendarDays.addDays(night, 1)
    ) {
      if (!isNight(night)) {
        return true;
      }
    }

    return false;
  }
}
