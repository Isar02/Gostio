import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';

void main() {
  final DateRange stay = DateRange(
    from: DateTime(2026, 6, 12),
    to: DateTime(2026, 6, 15),
  );

  // The twelfth to the fifteenth is three nights, and the fifteenth is free
  // for somebody else.
  test('a stay is as many nights as it covers, not days', () {
    expect(stay.nights, 3);
  });

  test('the night a stay ends on belongs to the next reader', () {
    expect(stay.holdsNight(DateTime(2026, 6, 12)), isTrue);
    expect(stay.holdsNight(DateTime(2026, 6, 14)), isTrue);
    expect(stay.holdsNight(DateTime(2026, 6, 15)), isFalse);
  });

  test('the night before a stay is not its own', () {
    expect(stay.holdsNight(DateTime(2026, 6, 11)), isFalse);
  });

  test('a night given with a time on it is still that night', () {
    expect(stay.holdsNight(DateTime(2026, 6, 14, 23, 30)), isTrue);
  });

  test('two stays over the same nights are the same stay', () {
    expect(
      stay,
      DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 15)),
    );
  });

  // Two readers who chose the same nights hold the same stay, whatever hour
  // of the day the dates were built at.
  test('a range keeps calendar days rather than the moment it was built', () {
    expect(
      DateRange(
        from: DateTime(2026, 6, 12, 14, 30),
        to: DateTime(2026, 6, 15, 9),
      ),
      stay,
    );
  });

  test('a stay that runs backwards is not a stay', () {
    expect(
      () => DateRange(from: DateTime(2026, 6, 15), to: DateTime(2026, 6, 12)),
      throwsArgumentError,
    );
  });

  test('a stay holding no night at all is not a stay', () {
    expect(
      () => DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 12)),
      throwsArgumentError,
    );
  });

  test('a single night is one night', () {
    expect(
      DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 13)).nights,
      1,
    );
  });
}
