import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/trips/presentation/trip_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/payment_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';
import '../../../support/trips_double.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    Reservation booking, {
    TripsDouble? trips,
    ValueChanged<Reservation>? onChanged,
  }) => pushOnto(
    tester,
    TripScreen(booking, onChanged: onChanged),
    auth: AuthDouble(),
    payments: PaymentDouble(),
    cardSheet: CardSheetDouble(),
    trips: trips ?? TripsDouble(),
  );

  Future<void> openTheSheet(WidgetTester tester) async {
    await tester.tap(find.text('Cancel this booking'));
    await tester.pumpAndSettle();
  }

  Future<void> callOff(
    WidgetTester tester, {
    String reason = 'Plans changed',
  }) async {
    await tester.enterText(find.byType(TextFormField), reason);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel the booking'));
    await tester.pumpAndSettle();
  }

  testWidgets('a trip says where it stands, what it is for and what it cost', (
    WidgetTester tester,
  ) async {
    final Reservation booking = stayBooking();
    await open(tester, booking);

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Loft over the river'), findsOneWidget);
    expect(find.text(AppDates.day(booking.checkInDate!)), findsOneWidget);
    expect(find.text('3 nights'), findsOneWidget);
    expect(find.text('285.00 KM'), findsNWidgets(2));
  });

  // A booking against a term says when that term begins without the screen
  // reading the term back: the row it was drawn from carries the hour.
  testWidgets('a trip on a term says when the term begins', (
    WidgetTester tester,
  ) async {
    final DateTime begins = DateTime.utc(2026, 7, 14, 7);
    await open(tester, termBooking(startTime: begins));

    expect(find.text('Starts'), findsOneWidget);
    expect(find.text(AppDates.dateTime(begins)), findsOneWidget);
  });

  testWidgets('a trip that is paid for says so and is asked for nothing', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      stayBooking(isPaid: true, standing: ReservationStatus.confirmed),
    );

    expect(find.text('This booking is paid for.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
  });

  // The server refuses a charge on a booking that has ended, and a bar that
  // carries a figure on one says money is owed where none is.
  testWidgets(
    'a trip that was called off is neither paid nor cancelled again',
    (WidgetTester tester) async {
      await open(tester, stayBooking(standing: ReservationStatus.cancelled));

      expect(find.text('This booking was called off.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
      expect(find.text('Cancel this booking'), findsNothing);
    },
  );

  testWidgets('a trip still holding its place is offered the charge', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking());

    final FilledButton pay = tester.widget(
      find.widgetWithText(FilledButton, 'Pay'),
    );

    expect(pay.onPressed, isNotNull);
    expect(find.text('Due now'), findsOneWidget);
  });

  // What calling the booking off sends back is part of the decision, so it is
  // read as the sheet opens and the button waits for it.
  testWidgets('cancelling says what comes back before it is agreed to', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = TripsDouble(
      quote: owedBack(amount: 142.50, percentage: 50),
    );
    await open(tester, stayBooking(), trips: trips);
    await openTheSheet(tester);

    expect(trips.quoted, <int>[501]);
    expect(
      find.text(
        '142.50 KM of 285.00 KM goes back, which is 50% of what was paid.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a booking nobody paid for is told that nothing goes back', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      stayBooking(),
      trips: TripsDouble(quote: owedBack(isPaid: false, charged: 285)),
    );
    await openTheSheet(tester);

    expect(
      find.text('Nothing was charged for this booking, so nothing goes back.'),
      findsOneWidget,
    );
  });

  // The server works the amount out either way, so a quote that could not be
  // read is not a reason to withhold the cancellation.
  testWidgets(
    'a quote that could not be read leaves the cancellation on offer',
    (WidgetTester tester) async {
      await open(
        tester,
        stayBooking(),
        trips: TripsDouble(
          quoteFailure: ApiException(message: 'No.', statusCode: 500),
        ),
      );
      await openTheSheet(tester);

      final FilledButton confirm = tester.widget(
        find.widgetWithText(FilledButton, 'Cancel the booking'),
      );

      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(confirm.onPressed, isNotNull);
    },
  );

  testWidgets('the server is told why, and refuses to be told nothing', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = TripsDouble();
    await open(tester, stayBooking(), trips: trips);
    await openTheSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel the booking'));
    await tester.pumpAndSettle();

    expect(trips.calledOff, isEmpty);
    expect(
      find.text('Say why the reservation is being cancelled.'),
      findsOneWidget,
    );

    await callOff(tester, reason: 'Plans changed');

    expect(trips.calledOff.single.bookingId, 501);
    expect(trips.calledOff.single.reason, 'Plans changed');
  });

  // The row the cancellation answered is what the screen draws from then on,
  // and what the list this was opened from is told.
  testWidgets('the booking the server answered replaces the one on screen', (
    WidgetTester tester,
  ) async {
    final List<Reservation> told = <Reservation>[];
    await open(tester, stayBooking(), onChanged: told.add);
    await openTheSheet(tester);
    await callOff(tester);

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('This booking was called off.'), findsOneWidget);
    expect(find.text('Cancel this booking'), findsNothing);
    expect(told.single.status, 'Cancelled');
  });

  testWidgets('a refused cancellation stays on the sheet in the server words', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      stayBooking(),
      trips: TripsDouble(
        cancelFailure: ApiException(
          message: 'This stay has already begun.',
          statusCode: 400,
        ),
      ),
    );
    await openTheSheet(tester);
    await callOff(tester);

    expect(find.text('This stay has already begun.'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  // The write outlives the sheet. What the server did reaches the screen
  // whether or not the reader is still looking at the sheet that asked for it,
  // and the screen behind is never closed by an answer meant for the sheet.
  testWidgets(
    'a cancellation that lands after the sheet was left still lands',
    (WidgetTester tester) async {
      final List<Reservation> told = <Reservation>[];
      final TripsDouble trips = TripsDouble(holdsTheCancellation: true);
      await open(tester, stayBooking(), trips: trips, onChanged: told.add);
      await openTheSheet(tester);

      await tester.enterText(find.byType(TextFormField), 'Plans changed');
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel the booking'));
      await tester.pump();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The write belongs to the trip route now, so leaving its sheet cannot
      // expose either competing action while the server is still answering.
      expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
      expect(find.text('Cancel this booking'), findsNothing);

      trips.answerTheCancellation();
      await tester.pumpAndSettle();

      expect(find.text('Your booking'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('This booking was called off.'), findsOneWidget);
      expect(find.text('Cancel this booking'), findsNothing);
      expect(told.single.status, 'Cancelled');
    },
  );

  // A sheet holding something the reader typed asks before it is left.
  testWidgets('a reason that was typed is not discarded without a question', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking());
    await openTheSheet(tester);

    await tester.enterText(find.byType(TextFormField), 'Plans changed');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Leave this form?'), findsOneWidget);
  });
}
