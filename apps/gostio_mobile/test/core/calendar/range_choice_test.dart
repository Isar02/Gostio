import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/core/calendar/range_choice.dart';

void main() {
  final DateTime first = DateTime(2026, 6);
  DateTime june(int day) => DateTime(2026, 6, day);

  RangeChoice empty({DateTime? lastDay}) =>
      RangeChoice(firstDay: first, lastDay: lastDay);

  bool everyNight(DateTime night) => true;

  // The nights of one week are sold and the rest of the month is not.
  bool exceptTheFifteenth(DateTime night) => night != june(15);

  test('the first tap opens a range and the second closes it', () {
    final RangeChoice chosen = empty()
        .take(june(12), isNight: everyNight)
        .take(june(15), isNight: everyNight);

    expect(chosen.range, DateRange(from: june(12), to: june(15)));
  });

  test('a range is not closed until a second day is taken', () {
    final RangeChoice chosen = empty().take(june(12), isNight: everyNight);

    expect(chosen.from, june(12));
    expect(chosen.range, isNull);
  });

  test('a second tap on or before the first night opens a new range', () {
    final RangeChoice chosen = empty()
        .take(june(12), isNight: everyNight)
        .take(june(9), isNight: everyNight);

    expect(chosen.from, june(9));
    expect(chosen.range, isNull);
  });

  // A stay occupies the nights up to the day it ends on, so the day the reader
  // leaves may already belong to somebody else.
  test('the day a stay ends on may be a night that is sold', () {
    final RangeChoice open = empty().take(
      june(12),
      isNight: exceptTheFifteenth,
    );

    expect(open.mayTake(june(15), isNight: exceptTheFifteenth), isTrue);
    expect(
      open.take(june(15), isNight: exceptTheFifteenth).range,
      DateRange(from: june(12), to: june(15)),
    );
  });

  // A second tap that cannot close a range opens a new one rather than
  // refusing the gesture, because a reader who tapped a day meant to take it.
  test('a range is not closed across a night somebody else holds', () {
    final RangeChoice open = empty().take(
      june(12),
      isNight: exceptTheFifteenth,
    );
    final RangeChoice again = open.take(june(17), isNight: exceptTheFifteenth);

    expect(again.from, june(17));
    expect(again.range, isNull);
  });

  // A night that is sold and cannot end a stay either answers nothing at all.
  test('a night somebody else holds answers no tap of its own', () {
    expect(empty().mayTake(june(15), isNight: exceptTheFifteenth), isFalse);
  });

  test('a day outside the window answers no tap at either end', () {
    final RangeChoice window = empty(lastDay: june(20));

    expect(window.mayTake(DateTime(2026, 5, 30), isNight: everyNight), isFalse);
    expect(window.mayTake(june(21), isNight: everyNight), isFalse);
    expect(
      window
          .take(june(12), isNight: everyNight)
          .mayTake(june(21), isNight: everyNight),
      isFalse,
    );
  });

  // Availability moves while the reader is elsewhere, so a range chosen before
  // one of its nights was sold is checked rather than trusted.
  test('a range whose night has gone is no longer one this window holds', () {
    final DateRange over = DateRange(from: june(12), to: june(17));

    expect(empty().holds(over, isNight: everyNight), isTrue);
    expect(empty().holds(over, isNight: exceptTheFifteenth), isFalse);
  });

  test('clearing drops both ends and keeps the window they were taken in', () {
    final RangeChoice cleared = empty(lastDay: june(20))
        .take(june(12), isNight: everyNight)
        .take(june(15), isNight: everyNight)
        .cleared;

    expect(cleared, empty(lastDay: june(20)));
  });
}
