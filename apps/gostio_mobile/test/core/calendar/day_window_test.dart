import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/day_window.dart';

void main() {
  final DayWindow window = DayWindow(
    from: DateTime(2026, 6, 12),
    to: DateTime(2026, 6, 14),
  );

  // The difference from a stay: a term is attended at a moment, so looking for
  // one on a single afternoon is a whole question rather than an empty range.
  test('a window may open and close on the same day', () {
    final DayWindow day = DayWindow.onOneDay(DateTime(2026, 6, 12));

    expect(day.isOneDay, isTrue);
    expect(day.days, 1);
  });

  test('a window counts both of the days it ends on', () {
    expect(window.days, 3);
  });

  test('a window that ends before it opens is refused', () {
    expect(
      () => DayWindow(from: DateTime(2026, 6, 14), to: DateTime(2026, 6, 12)),
      throwsArgumentError,
    );
  });

  test('the day a window closes on is inside it', () {
    expect(window.holds(DateTime(2026, 6, 12)), isTrue);
    expect(window.holds(DateTime(2026, 6, 14)), isTrue);
    expect(window.holds(DateTime(2026, 6, 15)), isFalse);
    expect(window.holds(DateTime(2026, 6, 11)), isFalse);
  });

  test('a day given with a time on it is still that day', () {
    expect(window.holds(DateTime(2026, 6, 14, 23, 30)), isTrue);
  });

  test('a window keeps calendar days rather than the moment it was built', () {
    expect(
      DayWindow(
        from: DateTime(2026, 6, 12, 14, 30),
        to: DateTime(2026, 6, 14, 9),
      ),
      window,
    );
  });
}
