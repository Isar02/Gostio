import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('the seeded keys name the statuses this client knows', () {
    expect(ReservationStatus.forId(1), ReservationStatus.pending);
    expect(ReservationStatus.forId(2), ReservationStatus.confirmed);
    expect(ReservationStatus.forId(3), ReservationStatus.cancelled);
    expect(ReservationStatus.forId(4), ReservationStatus.completed);
    expect(ReservationStatus.forId(9), isNull);
  });

  // The server's state machine, mirrored: a booking is confirmed out of
  // pending alone, and called off out of the two standings that still hold a
  // place. An ending is an ending, so neither of the other two moves anywhere.
  test('only a pending booking is confirmed', () {
    expect(ReservationStatus.pending.canBeConfirmed, isTrue);
    expect(ReservationStatus.confirmed.canBeConfirmed, isFalse);
    expect(ReservationStatus.cancelled.canBeConfirmed, isFalse);
    expect(ReservationStatus.completed.canBeConfirmed, isFalse);
  });

  test('a booking that still holds a place is the one that is called off', () {
    expect(ReservationStatus.pending.canBeCancelled, isTrue);
    expect(ReservationStatus.confirmed.canBeCancelled, isTrue);
    expect(ReservationStatus.cancelled.canBeCancelled, isFalse);
    expect(ReservationStatus.completed.canBeCancelled, isFalse);
  });
}
