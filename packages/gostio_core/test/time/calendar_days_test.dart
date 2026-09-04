import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('a week begins on the Monday on or before the day', () {
    expect(
      CalendarDays.startOfWeek(DateTime(2026, 9, 3)),
      DateTime(2026, 8, 31),
    );
    expect(
      CalendarDays.startOfWeek(DateTime(2026, 8, 31)),
      DateTime(2026, 8, 31),
    );
    expect(
      CalendarDays.startOfWeek(DateTime(2026, 9, 6)),
      DateTime(2026, 8, 31),
    );
  });

  // The clocks go forward on 29 March 2026, and that day is 23 hours long.
  test('a day added over a clock change is still the next date', () {
    expect(
      CalendarDays.addDays(DateTime(2026, 3, 28), 2),
      DateTime(2026, 3, 30),
    );
    expect(
      CalendarDays.daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)),
      2,
    );
  });

  test('months are added through the calendar rather than through days', () {
    expect(CalendarDays.addMonths(DateTime(2026, 12), 1), DateTime(2027));
    expect(CalendarDays.addMonths(DateTime(2026), -1), DateTime(2025, 12));
    expect(CalendarDays.firstOfMonth(DateTime(2026, 9, 30)), DateTime(2026, 9));
  });

  test('a day is written in the form the API binds a date from', () {
    expect(CalendarDays.write(DateTime(2026, 9, 3)), '2026-09-03');
    expect(CalendarDays.write(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
