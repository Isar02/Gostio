import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/overview/data/overview_month.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';

import '../../../support/booking_fixture.dart';

void main() {
  test('the month is the days it actually has', () {
    expect(_month(month: DateTime(2026, 9)).days, hasLength(30));
    expect(_month(month: DateTime(2026, 2)).days, hasLength(28));
    expect(_month(month: DateTime(2028, 2)).days, hasLength(29));
  });

  test('a listing with nothing booked is still a row', () {
    final OverviewMonth month = _month();

    expect(month.rows, hasLength(2));
    expect(month.rows.first.spans, isEmpty);
    expect(month.isQuiet, isTrue);
  });

  // A stay takes the nights between its two dates, so the day it ends on
  // belongs to the next guest and is not one of the days it covers.
  test('a stay covers its nights and not the day it ends on', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          accommodationId: 4,
          checkInDate: DateTime(2026, 9, 10),
          checkOutDate: DateTime(2026, 9, 14),
        ),
      ],
    );
    final OverviewSpan span = month.rows.first.spans.single;

    expect(span.column, 9);
    expect(span.span, 4);
    expect(span.startsHere, isTrue);
    expect(span.endsHere, isTrue);
    expect(month.bookedNights, 4);
  });

  test('a stay is laid on the listing it was made against', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          accommodationId: 9,
          checkInDate: DateTime(2026, 9, 3),
          checkOutDate: DateTime(2026, 9, 5),
        ),
      ],
    );

    expect(month.rows.first.spans, isEmpty);
    expect(month.rows.last.spans.single.column, 2);
  });

  // A block that stops at the edge is not a stay that ends on it, so the two
  // are told apart rather than drawn the same.
  test('a stay reaching past either edge is clipped and left open', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          accommodationId: 4,
          checkInDate: DateTime(2026, 8, 28),
          checkOutDate: DateTime(2026, 10, 3),
        ),
      ],
    );
    final OverviewSpan span = month.rows.first.spans.single;

    expect(span.column, 0);
    expect(span.span, 30);
    expect(span.startsHere, isFalse);
    expect(span.endsHere, isFalse);
  });

  test('a stay that ends before the month opens is not drawn', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          accommodationId: 4,
          checkInDate: DateTime(2026, 8, 20),
          checkOutDate: DateTime(2026, 9),
        ),
      ],
    );

    expect(month.rows.first.spans, isEmpty);
  });

  // A cancelled booking holds nothing, so the days it named are free again.
  test('a cancelled booking is not drawn', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          accommodationId: 4,
          reservationStatusId: 3,
          status: 'Cancelled',
          checkInDate: DateTime(2026, 9, 10),
          checkOutDate: DateTime(2026, 9, 14),
        ),
      ],
    );

    expect(month.rows.first.spans, isEmpty);
    expect(month.arrivals, isEmpty);
  });

  // A term carries a slot instead of two dates, and the window that brought it
  // back is simply wider than what a month of stays draws.
  test('a term booking is placed nowhere', () {
    final OverviewMonth month = _month(bookings: <Reservation>[termBooking()]);

    expect(month.isQuiet, isTrue);
    expect(month.arrivals, isEmpty);
    expect(month.departures, isEmpty);
  });

  test('arrivals and departures are the movements inside the month', () {
    final OverviewMonth month = _month(
      bookings: <Reservation>[
        booking(
          id: 1,
          accommodationId: 4,
          checkInDate: DateTime(2026, 8, 30),
          checkOutDate: DateTime(2026, 9, 4),
        ),
        booking(
          id: 2,
          accommodationId: 9,
          checkInDate: DateTime(2026, 9, 20),
          checkOutDate: DateTime(2026, 10, 2),
        ),
      ],
    );

    expect(
      month.arrivals.map((OverviewMovement move) => move.booking.id),
      <int>[2],
    );
    expect(
      month.departures.map((OverviewMovement move) => move.booking.id),
      <int>[1],
    );
  });

  test('a movement is read against today rather than as a bare date', () {
    final OverviewMonth month = _month(
      today: DateTime(2026, 9, 12),
      bookings: <Reservation>[
        booking(
          id: 1,
          accommodationId: 4,
          checkInDate: DateTime(2026, 9, 13),
          checkOutDate: DateTime(2026, 9, 16),
        ),
        booking(
          id: 2,
          accommodationId: 9,
          checkInDate: DateTime(2026, 9, 4),
          checkOutDate: DateTime(2026, 9, 8),
        ),
      ],
    );

    expect(month.arrivals.first.daysAhead, -8);
    expect(month.arrivals.first.isPast, isTrue);
    expect(month.arrivals.last.daysAhead, 1);
    expect(month.arrivals.last.isPast, isFalse);
  });

  test('a host with no listing at all says so on its own', () {
    expect(_month(listings: const <LookupItem>[]).hasNoListings, isTrue);
    expect(_month().hasNoListings, isFalse);
  });
}

OverviewMonth _month({
  DateTime? month,
  DateTime? today,
  List<LookupItem> listings = const <LookupItem>[
    LookupItem(id: 4, name: 'Stone villa on the hill above Neum'),
    LookupItem(id: 9, name: 'Loft over the old bazaar'),
  ],
  List<Reservation> bookings = const <Reservation>[],
}) => OverviewMonth.of(
  month: month ?? DateTime(2026, 9),
  listings: listings,
  bookings: bookings,
  today: today ?? DateTime(2026, 9, 4),
);
