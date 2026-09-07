import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/booking/presentation/booking_screen.dart';
import 'package:gostio_mobile/features/payment/data/card_sheet.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/payment_double.dart';
import '../../../support/phone.dart';
import '../../../support/push_double.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    Reservation booking, {
    ExperienceSlot? term,
    PaymentDouble? payments,
    CardSheetDouble? sheet,
    PushMessagingDouble? messaging,
  }) => pushOnto(
    tester,
    BookingScreen(booking, term: term),
    auth: AuthDouble(),
    payments: payments ?? PaymentDouble(),
    cardSheet: sheet ?? CardSheetDouble(),
    messaging: messaging,
  );

  Future<void> tapPay(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pay now'));
    await tester.pumpAndSettle();
  }

  testWidgets('a booked stay says its dates, its party and its figures', (
    WidgetTester tester,
  ) async {
    final Reservation booking = stayBooking();
    await open(tester, booking);

    expect(find.text('Your booking'), findsOneWidget);
    expect(find.text('Loft over the river'), findsOneWidget);
    expect(find.text(AppDates.day(booking.checkInDate!)), findsOneWidget);
    expect(find.text(AppDates.day(booking.checkOutDate!)), findsOneWidget);
    expect(find.text('2 guests'), findsOneWidget);
    expect(find.text('3 nights'), findsOneWidget);
    expect(find.text('270.00 KM'), findsOneWidget);
    expect(find.text('Cleaning fee'), findsOneWidget);

    // The total is under the figures it is made of, and again beside the
    // button that settles it.
    expect(find.text('285.00 KM'), findsNWidgets(2));
  });

  // A term carries the hour it begins rather than a pair of dates, and the
  // booking row does not hold that hour: the screen that chose it hands it on.
  testWidgets('a booked term says when it begins and how long it runs', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      termBooking(experienceSlotId: 4),
      term: experienceSlot(
        id: 4,
        startTime: DateTime.utc(2026, 7, 14, 7),
        durationMinutes: 180,
      ),
    );

    expect(find.text('Old town walk'), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('50.00 KM'), findsNWidgets(3));
  });

  // A hold nobody mentioned is a booking that quietly disappears.
  testWidgets('the hold is counted down and says what runs out with it', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking(heldFor: const Duration(hours: 3)));

    expect(
      find.textContaining('Held for 2 h 59 min. It is released if it has not'),
      findsOneWidget,
    );
  });

  testWidgets('a hold that has already run out says so instead', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking(heldFor: Duration.zero));

    expect(find.text('The hold on this booking ran out.'), findsOneWidget);
  });

  // The server refuses a charge on a place that is no longer held, and a
  // button that has to be pressed to learn that is a button that lied.
  testWidgets('a booking whose hold ran out is not offered a payment', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking(heldFor: Duration.zero));

    final FilledButton pay = tester.widget(
      find.widgetWithText(FilledButton, 'Pay'),
    );

    expect(pay.onPressed, isNull);
  });

  testWidgets('paying is agreed to before the card sheet opens', (
    WidgetTester tester,
  ) async {
    final CardSheetDouble sheet = CardSheetDouble(holdsTheSheet: true);
    await open(tester, stayBooking(), sheet: sheet);

    await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
    await tester.pumpAndSettle();

    expect(find.text('Pay for this booking?'), findsOneWidget);
    expect(
      find.textContaining('takes 285.00 KM for Loft over the river'),
      findsOneWidget,
    );
    expect(sheet.presented, isEmpty);
  });

  testWidgets('the screen calls the booking paid only once the server does', (
    WidgetTester tester,
  ) async {
    final PaymentDouble payments = PaymentDouble(
      reads: <Reservation>[stayBooking(isPaid: true)],
    );
    await open(tester, stayBooking(), payments: payments);

    await tapPay(tester);

    expect(
      find.text('Payment sent. Confirming it with the card processor.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('This booking is paid for.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
    expect(find.textContaining('Held for'), findsNothing);
  });

  testWidgets('a payment the server has not confirmed says what to do next', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking(), payments: PaymentDouble());

    await tapPay(tester);
    for (int attempt = 0; attempt < 10; attempt++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no confirmation has reached us yet'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Ask again'), findsOneWidget);
  });

  testWidgets('a sheet that could not open is said beside the button', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      stayBooking(),
      sheet: CardSheetDouble(
        answer: const CardSheetRefused('The card sheet could not be opened.'),
      ),
    );

    await tapPay(tester);

    expect(find.text('The card sheet could not be opened.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
  });

  testWidgets('a booking the server calls paid is offered no way to pay', (
    WidgetTester tester,
  ) async {
    await open(tester, stayBooking(isPaid: true));

    expect(find.text('This booking is paid for.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
    expect(find.text('285.00 KM'), findsOneWidget);
  });

  // The first moment in the client that there is something to be notified
  // about — a hold that lapses, a host who confirms. Asked on the first frame
  // of the first launch instead, the only honest answer would be no.
  testWidgets('a booking that lands is where the phone is asked to notify', (
    WidgetTester tester,
  ) async {
    final PushMessagingDouble messaging = PushMessagingDouble();
    await open(tester, stayBooking(), messaging: messaging);

    expect(messaging.askCalls, 1);

    await messaging.close();
  });
}
