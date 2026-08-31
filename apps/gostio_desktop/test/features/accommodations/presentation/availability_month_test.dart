import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability.dart';
import 'package:gostio_desktop/features/accommodations/presentation/availability_month.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';

void main() {
  test('a booking fills its nights and leaves the day it ends on free', () {
    final AvailabilityMonth month = _month(
      bookings: <Reservation>[_booking(arrives: 3, departs: 6)],
    );

    expect(_on(month, 2).booking, isNull);
    expect(_on(month, 3).booking, isNotNull);
    expect(_on(month, 5).booking, isNotNull);
    expect(_on(month, 6).booking, isNull);
    expect(month.bookedNights, 3);
  });

  test('an entry covers both the days it names', () {
    final AvailabilityMonth month = _month(
      entries: <AccommodationAvailability>[_blocked(from: 3, to: 5)],
    );

    expect(_on(month, 2).isBlocked, isFalse);
    expect(_on(month, 3).isBlocked, isTrue);
    expect(_on(month, 5).isBlocked, isTrue);
    expect(_on(month, 6).isBlocked, isFalse);
    expect(month.blockedDays, 3);
  });

  test('a cancelled booking leaves the nights it named free', () {
    final AvailabilityMonth month = _month(
      bookings: <Reservation>[
        _booking(arrives: 3, departs: 5, statusId: _cancelled),
        _booking(id: 2, arrives: 10, departs: 12, statusId: _completed),
      ],
    );

    expect(_on(month, 3).booking, isNull);
    expect(_on(month, 10).booking, isNotNull);
  });

  test('a stay crossing a Sunday is drawn open at the edge it runs over', () {
    // September 2026 begins on a Tuesday, so 6 September is a Sunday.
    final AvailabilityMonth month = _month(
      bookings: <Reservation>[_booking(arrives: 4, departs: 9)],
    );

    final List<BookingBar> bars = month.weeks
        .expand((AvailabilityWeek week) => week.bars)
        .toList();

    expect(bars.length, 2);
    expect(bars.first.span, 3);
    expect(bars.first.startsHere, isTrue);
    expect(bars.first.endsHere, isFalse);
    expect(bars.last.span, 2);
    expect(bars.last.startsHere, isFalse);
    expect(bars.last.endsHere, isTrue);
  });

  test('the counts are of the month rather than of the grid around it', () {
    final AvailabilityMonth month = _month(
      entries: <AccommodationAvailability>[
        AccommodationAvailability(
          id: 1,
          accommodationId: 7,
          startDate: DateTime(2026, 8, 28),
          endDate: DateTime(2026, 9, 2),
          isAvailable: false,
        ),
      ],
    );

    expect(month.weeks.length, 6);
    expect(month.days.length, 42);
    expect(month.blockedDays, 2);
    expect(_on(month, 2).isBlocked, isTrue);
  });

  test('a span reaching over an entry is known before it is written', () {
    final AvailabilityMonth month = _month(
      entries: <AccommodationAvailability>[_blocked(from: 10, to: 12)],
    );

    expect(
      month.hasAnEntryBetween(
        from: DateTime(2026, 9, 8),
        to: DateTime(2026, 9, 9),
      ),
      isFalse,
    );
    expect(
      month.hasAnEntryBetween(
        from: DateTime(2026, 9, 8),
        to: DateTime(2026, 9, 14),
      ),
      isTrue,
    );
  });

  test('the booked nights inside a span are counted for the dialog', () {
    final AvailabilityMonth month = _month(
      bookings: <Reservation>[_booking(arrives: 10, departs: 13)],
    );

    expect(
      month.bookedNightsBetween(
        from: DateTime(2026, 9, 9),
        to: DateTime(2026, 9, 11),
      ),
      2,
    );
  });
}

const int _pending = 1;
const int _cancelled = 3;
const int _completed = 4;

AvailabilityMonth _month({
  List<AccommodationAvailability> entries = const <AccommodationAvailability>[],
  List<Reservation> bookings = const <Reservation>[],
}) => AvailabilityMonth.of(
  month: DateTime(2026, 9),
  entries: entries,
  bookings: bookings,
  today: DateTime(2026, 9, 15),
);

AvailabilityDay _on(AvailabilityMonth month, int day) => month.days.firstWhere(
  (AvailabilityDay candidate) =>
      candidate.date == DateTime(2026, 9, day) && candidate.isInMonth,
);

AccommodationAvailability _blocked({required int from, required int to}) =>
    AccommodationAvailability(
      id: 1,
      accommodationId: 7,
      startDate: DateTime(2026, 9, from),
      endDate: DateTime(2026, 9, to),
      isAvailable: false,
    );

Reservation _booking({
  int id = 1,
  required int arrives,
  required int departs,
  int statusId = _pending,
}) => Reservation(
  id: id,
  guestName: 'Ana',
  guestCount: 2,
  reservationStatusId: statusId,
  status: 'Pending',
  checkInDate: DateTime(2026, 9, arrives),
  checkOutDate: DateTime(2026, 9, departs),
);
