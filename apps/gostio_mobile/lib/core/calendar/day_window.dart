import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A run of whole days with both ends inside it. This is the closed half of the
// pair [DateRange] opens: a stay holds the nights between two dates and cannot
// hold none, while a term is attended at a moment, so a window looking for one
// may open and close on the same day.
//
// Getting that difference wrong is the mistake the two names exist to prevent,
// which is why they are separate types rather than one carrying a flag.
@immutable
class DayWindow {
  factory DayWindow({required DateTime from, required DateTime to}) {
    final DateTime first = CalendarDays.of(from);
    final DateTime last = CalendarDays.of(to);

    if (last.isBefore(first)) {
      throw ArgumentError.value(
        to,
        'to',
        'A window ends on or after ${CalendarDays.write(first)}',
      );
    }

    return DayWindow._(first, last);
  }

  factory DayWindow.onOneDay(DateTime day) => DayWindow(from: day, to: day);

  const DayWindow._(this.from, this.to);

  // Both ends are calendar days rather than moments, so two readers who chose
  // the same days hold the same window whatever hour they chose it at.
  final DateTime from;
  final DateTime to;

  int get days => CalendarDays.daysBetween(from, to) + 1;

  bool get isOneDay => from == to;

  bool holds(DateTime day) {
    final DateTime asked = CalendarDays.of(day);

    return !asked.isBefore(from) && !asked.isAfter(to);
  }

  @override
  bool operator ==(Object other) =>
      other is DayWindow && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() =>
      'DayWindow(${CalendarDays.write(from)} to ${CalendarDays.write(to)})';
}
