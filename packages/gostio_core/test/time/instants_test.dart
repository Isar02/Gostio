import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('a moment is written in UTC, padded and without an offset', () {
    expect(
      Instants.write(DateTime.utc(2026, 9, 2, 7, 5, 4)),
      '2026-09-02T07:05:04.000000',
    );
  });

  test('a moment is written to the microsecond', () {
    expect(
      Instants.write(DateTime.utc(2026, 9, 2, 21, 59, 59, 999, 999)),
      '2026-09-02T21:59:59.999999',
    );
  });

  test('a local moment is converted before it is written', () {
    final DateTime local = DateTime(2026, 9, 2, 12);

    expect(Instants.write(local), Instants.write(local.toUtc()));
  });

  // The column counts in hundreds of nanoseconds, so the end of a day is the
  // last of those rather than the last second or the last microsecond.
  test('the end of a day is the last tick inside it', () {
    final String written = Instants.endOfDay(DateTime(2026, 9, 2));
    final DateTime meant = DateTime.parse('${written}Z');

    expect(written, endsWith('.9999999'));
    expect(meant.isBefore(DateTime(2026, 9, 3).toUtc()), isTrue);
    expect(meant.isAfter(DateTime(2026, 9, 2, 23, 59, 59).toUtc()), isTrue);
  });
}
