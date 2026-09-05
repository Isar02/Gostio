import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/trips/data/trip_window.dart';
import 'package:gostio_mobile/features/trips/presentation/trip_card.dart';
import 'package:gostio_mobile/features/trips/presentation/trips_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/payment_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';
import '../../../support/trips_double.dart';

void main() {
  setUp(usePhoneScreen);

  Future<TripsDouble> openTrips(
    WidgetTester tester, {
    TripsDouble? trips,
  }) async {
    final TripsDouble double = trips ?? TripsDouble();

    await tester.pumpWidget(
      underTest(
        // The bar over this is the shell's, so what a test draws is the body
        // the shell puts under it.
        const Scaffold(body: SafeArea(child: TripsScreen(guestId: 12))),
        auth: AuthDouble(),
        trips: double,
        payments: PaymentDouble(),
        cardSheet: CardSheetDouble(),
      ),
    );
    await tester.pumpAndSettle();

    return double;
  }

  Future<void> show(WidgetTester tester, TripWindow window) async {
    await tester.tap(find.text(window.label));
    await tester.pumpAndSettle();
  }

  // The list is the account's own bookings rather than everything the caller
  // may see: a host reading this tab has bookings against their listings too.
  testWidgets('the tab opens on what is still ahead of this guest', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = await openTrips(
      tester,
      trips: TripsDouble(
        upcoming: <Reservation>[stayBooking()],
        past: <Reservation>[stayBooking(id: 502)],
      ),
    );

    expect(trips.asked.single.guestId, 12);
    expect(trips.asked.single.window, TripWindow.upcoming);
    expect(find.byType(TripCard), findsOneWidget);
    expect(find.text('1 of 1 bookings'), findsOneWidget);
  });

  testWidgets('a card says what was booked, when it is and where it stands', (
    WidgetTester tester,
  ) async {
    final Reservation booking = stayBooking();
    await openTrips(
      tester,
      trips: TripsDouble(upcoming: <Reservation>[booking]),
    );

    expect(find.text('Loft over the river'), findsOneWidget);
    expect(
      find.text(
        '${AppDates.day(booking.checkInDate!)} – '
        '${AppDates.day(booking.checkOutDate!)} · 3 nights',
      ),
      findsOneWidget,
    );
    expect(find.text('2 guests'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('285.00 KM'), findsOneWidget);
    expect(find.text('Not paid'), findsOneWidget);
  });

  // A booking against a term carries no dates, so the row says when the term
  // begins and the list never reads a term back to find out.
  testWidgets('a card on a term says when the term begins', (
    WidgetTester tester,
  ) async {
    final DateTime begins = DateTime.utc(2026, 7, 14, 7);
    await openTrips(
      tester,
      trips: TripsDouble(
        upcoming: <Reservation>[termBooking(startTime: begins)],
      ),
    );

    expect(find.text(AppDates.dateTime(begins)), findsOneWidget);
  });

  // A booking that ended without being paid for still says so; only one that
  // was called off says nothing, because it owes nothing either way.
  testWidgets('a booking that ended unpaid still says it was not paid', (
    WidgetTester tester,
  ) async {
    await openTrips(
      tester,
      trips: TripsDouble(
        past: <Reservation>[
          stayBooking(standing: ReservationStatus.completed),
          stayBooking(id: 503, standing: ReservationStatus.cancelled),
        ],
      ),
    );
    await show(tester, TripWindow.past);

    expect(find.text('Not paid'), findsOneWidget);
  });

  // A list with nothing in it is still a list, and the gesture that reads it
  // again is the only one it has.
  testWidgets('an empty list is read again by pulling on it', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = await openTrips(tester);

    expect(find.text('Nothing booked yet'), findsOneWidget);

    await tester.fling(
      find.text('Nothing booked yet'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(trips.asked.length, 2);
  });

  testWidgets('a booking that was paid for says so rather than what is owed', (
    WidgetTester tester,
  ) async {
    await openTrips(
      tester,
      trips: TripsDouble(
        past: <Reservation>[
          stayBooking(isPaid: true, standing: ReservationStatus.completed),
        ],
      ),
    );
    await show(tester, TripWindow.past);

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Not paid'), findsNothing);
  });

  testWidgets('the list behind the toggle is not read until it is shown', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = await openTrips(
      tester,
      trips: TripsDouble(past: <Reservation>[stayBooking()]),
    );

    expect(trips.asked.length, 1);

    await show(tester, TripWindow.past);

    expect(trips.asked.last.window, TripWindow.past);
    expect(trips.asked.length, 2);

    // Coming back to a list already read asks nothing: it is kept alive rather
    // than rebuilt, and what it holds is what the reader left.
    await show(tester, TripWindow.upcoming);
    await show(tester, TripWindow.past);

    expect(trips.asked.length, 2);
  });

  testWidgets('each side says in its own words when it holds nothing', (
    WidgetTester tester,
  ) async {
    await openTrips(tester);

    expect(find.text('Nothing booked yet'), findsOneWidget);

    await show(tester, TripWindow.past);

    expect(find.text('Nothing behind you yet'), findsOneWidget);
  });

  testWidgets('a list that was refused is answered with another go', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = await openTrips(
      tester,
      trips: TripsDouble(
        failure: ApiException(message: 'The server is down.', statusCode: 503),
      ),
    );

    expect(find.text('The server is down.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(trips.asked.length, 2);
  });

  // The list read the row before the screen it opened changed it, and reading
  // the whole list again would take one several pages deep back to its first.
  testWidgets('a booking called off on its own screen comes back to its card', (
    WidgetTester tester,
  ) async {
    await openTrips(
      tester,
      trips: TripsDouble(upcoming: <Reservation>[stayBooking()]),
    );

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel this booking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Plans changed');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel the booking'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });
}
