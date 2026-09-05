import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  final DateTime now = DateTime(2026, 6, 16, 11);

  Reservation booking({
    ReservationStatus standing = ReservationStatus.pending,
    DateTime? checkOutDate,
    DateTime? heldUntil,
    bool isPaid = false,
  }) => Reservation(
    id: 7,
    userId: 12,
    guestName: 'Emina Begić',
    listingTitle: 'Loft over the river',
    guestCount: 2,
    reservationStatusId: standing.index + 1,
    status: standing.name,
    totalPrice: 285,
    isPaid: isPaid,
    expiresAt: heldUntil ?? now.toUtc().add(const Duration(hours: 4)),
    createdAt: now.toUtc(),
    accommodationId: checkOutDate == null ? null : 1,
    checkInDate: checkOutDate == null ? null : DateTime(2026, 6, 13),
    checkOutDate: checkOutDate,
  );

  // A stay is measured in days, so the night it ends on decides this rather
  // than the hour the question is asked at.
  test('a stay whose last night has gone is over', () {
    expect(booking(checkOutDate: DateTime(2026, 6, 16)).isOverAt(now), isTrue);
    expect(booking(checkOutDate: DateTime(2026, 6, 17)).isOverAt(now), isFalse);
  });

  test(
    'a booking that was called off or finished is over whatever its dates',
    () {
      for (final ReservationStatus standing in <ReservationStatus>[
        ReservationStatus.cancelled,
        ReservationStatus.completed,
      ]) {
        expect(
          booking(
            standing: standing,
            checkOutDate: DateTime(2026, 7, 20),
          ).isOverAt(now),
          isTrue,
        );
      }
    },
  );

  // A booking against a term carries no dates, so only its standing ends it.
  test('a term booking that still stands is not over', () {
    expect(booking().isOverAt(now), isFalse);
  });

  test('a hold that has run out takes the charge with it', () {
    expect(
      booking(heldUntil: now.toUtc().subtract(const Duration(minutes: 1)))
          .canBePaidForAt(now),
      isFalse,
    );
    expect(booking().canBePaidForAt(now), isTrue);
  });

  // Confirming a booking is what replaces its hold, so the deadline the hold
  // was under stops deciding anything.
  test('a confirmed booking is payable after the hold it was made under', () {
    expect(
      booking(
        standing: ReservationStatus.confirmed,
        heldUntil: now.toUtc().subtract(const Duration(days: 2)),
      ).canBePaidForAt(now),
      isTrue,
    );
  });

  test('a booking that is paid for is not charged a second time', () {
    expect(booking(isPaid: true).canBePaidForAt(now), isFalse);
  });

  test('an ended booking is not charged at all', () {
    expect(
      booking(checkOutDate: DateTime(2026, 6, 16)).canBePaidForAt(now),
      isFalse,
    );
  });
}
