import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/features/trips/data/trip_window.dart';

void main() {
  final DateTime today = DateTime(2026, 6, 16);

  test('what is ahead is asked for from the day the reader is standing in', () {
    expect(TripWindow.upcoming.boundedOn(today), <String, dynamic>{
      'from': '2026-06-16',
    });
  });

  // The other side of the same day, which is what keeps a stay the reader is
  // on out of the list of what is behind them.
  test('what is behind is the same day asked from the other side', () {
    expect(TripWindow.past.boundedOn(today), <String, dynamic>{
      'endedBefore': '2026-06-16',
    });
  });

  test('neither window narrows the list by anything else', () {
    for (final TripWindow window in TripWindow.values) {
      expect(window.boundedOn(today).length, 1);
    }
  });
}
