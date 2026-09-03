import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';

void main() {
  test('a range goes as the two dates the API binds', () {
    final ReportRange range = ReportRange(
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 8, 31),
    );

    expect(range.toParameters(), <String, dynamic>{
      'from': '2026-01-01',
      'to': '2026-08-31',
    });
  });

  // A picker answers midnight, but a moment from anywhere else is a day too.
  test('a moment is held as the day it falls on', () {
    final ReportRange range = ReportRange(
      from: DateTime(2026, 1, 1, 18, 40),
      to: DateTime(2026, 8, 31, 23, 59),
    );

    expect(range.from, DateTime(2026, 1, 1));
    expect(range.to, DateTime(2026, 8, 31));
  });

  test('a range that ends before it starts is refused', () {
    final ReportRange range = ReportRange(
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 7, 31),
    );

    expect(range.isAskable, isFalse);
    expect(range.refusal, 'A report cannot end before it starts.');
  });

  // The count is of months touched rather than of months elapsed, so a range
  // inside one month covers one and a range over a boundary covers two.
  test('a month is covered by any part of it', () {
    expect(
      ReportRange(
        from: DateTime(2026, 3, 4),
        to: DateTime(2026, 3, 29),
      ).monthsCovered,
      1,
    );
    expect(
      ReportRange(
        from: DateTime(2026, 3, 31),
        to: DateTime(2026, 4, 1),
      ).monthsCovered,
      2,
    );
  });

  test('a range is asked up to the last month the server builds', () {
    final ReportRange longest = ReportRange(
      from: DateTime(2025, 1, 1),
      to: DateTime(2026, 12, 31),
    );

    expect(longest.monthsCovered, ReportRange.maximumMonths);
    expect(longest.isAskable, isTrue);

    final ReportRange past = longest.endingOn(DateTime(2027, 1, 1));

    expect(past.refusal, 'A report covers at most 24 months.');
  });

  test('the screen opens on this month and the eleven before it', () {
    final ReportRange opening = ReportRange.rollingYearToToday();
    final DateTime today = CalendarDays.today();

    expect(opening.to, today);
    expect(opening.from, DateTime(today.year, today.month - 11));
    expect(opening.monthsCovered, 12);
    expect(opening.isAskable, isTrue);
  });

  test('a range is the two days it names', () {
    expect(
      ReportRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 8, 31)),
      ReportRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 8, 31)),
    );
    expect(
      ReportRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 8, 31)),
      isNot(ReportRange(from: DateTime(2026, 1, 2), to: DateTime(2026, 8, 31))),
    );
  });
}
