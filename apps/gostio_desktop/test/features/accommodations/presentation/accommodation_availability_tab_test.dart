import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_availability_tab.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Availability(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The calendar could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Trace 62b0d4'), findsOneWidget);
  });

  testWidgets('a month with nothing on it says every night is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(), bookings: const <Reservation>[]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Every night this month is open at the listing price.'),
      findsOneWidget,
    );
  });

  testWidgets('the month counts its own nights and names its guests', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(rows: <AccommodationAvailability>[_blocked])),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nights this month: 1 booked · 3 blocked'),
      findsOneWidget,
    );
    expect(find.textContaining('Ana Marić'), findsWidgets);
  });
}

// Days of the month on screen that no neighbouring month can also draw: the
// grid carries at most six days before it and twelve after.
DateTime _on(int day) =>
    DateTime(CalendarDays.today().year, CalendarDays.today().month, day);

final AccommodationAvailability _blocked = AccommodationAvailability(
  id: 1,
  accommodationId: 7,
  startDate: _on(14),
  endDate: _on(16),
  isAvailable: false,
);

final Reservation _booking = Reservation(
  id: 1,
  guestName: 'Ana Marić',
  guestCount: 2,
  reservationStatusId: 2,
  status: 'Confirmed',
  checkInDate: _on(21),
  checkOutDate: _on(22),
);

Widget _tab(
  _Availability availability, {
  List<Reservation>? bookings,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<AccommodationAvailabilityRepository>.value(value: availability),
    Provider<ReservationsRepository>.value(
      value: _Reservations(bookings ?? <Reservation>[_booking]),
    ),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: AccommodationAvailabilityTab(accommodationId: 7, nightlyPrice: 120),
    ),
  ),
);

class _Availability implements AccommodationAvailabilityRepository {
  _Availability({
    this.failing = false,
    this.rows = const <AccommodationAvailability>[],
  });

  final bool failing;
  final List<AccommodationAvailability> rows;

  @override
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (failing) {
      throw const ApiException(
        message: 'The calendar could not be read.',
        statusCode: 500,
        traceId: '62b0d4',
      );
    }

    return rows;
  }

  @override
  Future<AccommodationAvailability> add(
    int accommodationId,
    AvailabilityDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(int accommodationId, int availabilityId) =>
      throw UnimplementedError();
}

class _Reservations implements ReservationsRepository {
  const _Reservations(this.rows);

  final List<Reservation> rows;

  @override
  Future<int> countForAccommodation(int accommodationId) =>
      throw UnimplementedError();

  @override
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async => rows;
}
