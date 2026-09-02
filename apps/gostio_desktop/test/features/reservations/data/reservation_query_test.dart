import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    const ReservationQuery query = ReservationQuery();

    expect(query.toParameters(), isEmpty);
    expect(query.isEmpty, isTrue);
  });

  test('a listing narrows the side of the catalogue it belongs to', () {
    const ReservationQuery stays = ReservationQuery(
      listing: ListingAddress(ListingKind.accommodation, 4),
    );
    const ReservationQuery terms = ReservationQuery(
      listing: ListingAddress(ListingKind.experience, 9),
    );

    expect(stays.toParameters(), <String, dynamic>{'accommodationId': 4});
    expect(terms.toParameters(), <String, dynamic>{'experienceId': 9});
  });

  test('a day reaches the request as the date the API binds', () {
    final ReservationQuery query = ReservationQuery(
      from: DateTime(2026, 9, 4),
      to: DateTime(2026, 9, 30),
      arrivesOn: DateTime(2026, 9, 7),
      departsOn: DateTime(2026, 10, 1),
    );

    expect(query.toParameters(), <String, dynamic>{
      'from': '2026-09-04',
      'to': '2026-09-30',
      'arrivesOn': '2026-09-07',
      'departsOn': '2026-10-01',
    });
  });

  test('every filter that was set reaches the request', () {
    final ReservationQuery query = ReservationQuery(
      listing: const ListingAddress(ListingKind.accommodation, 4),
      reservationStatusId: 2,
      isActive: true,
      from: DateTime(2026, 9, 4),
    );

    expect(query.toParameters(), <String, dynamic>{
      'accommodationId': 4,
      'reservationStatusId': 2,
      'isActive': true,
      'from': '2026-09-04',
    });
    expect(query.isEmpty, isFalse);
  });

  test('two queries that ask the same thing are the same query', () {
    expect(
      const ReservationQuery(reservationStatusId: 2, isActive: true),
      const ReservationQuery(reservationStatusId: 2, isActive: true),
    );
    expect(
      const ReservationQuery(
        listing: ListingAddress(ListingKind.accommodation, 4),
      ),
      isNot(
        const ReservationQuery(
          listing: ListingAddress(ListingKind.experience, 4),
        ),
      ),
    );
  });
}
