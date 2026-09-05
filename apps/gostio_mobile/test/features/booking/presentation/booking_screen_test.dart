import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/features/booking/presentation/booking_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('a booked stay says its dates, its party and its figures', (
    WidgetTester tester,
  ) async {
    await pushOnto(tester, BookingScreen(stayBooking()), auth: AuthDouble());

    expect(find.text('Your booking'), findsOneWidget);
    expect(find.text('Loft over the river'), findsOneWidget);
    expect(find.text('12 Jun 2026'), findsOneWidget);
    expect(find.text('15 Jun 2026'), findsOneWidget);
    expect(find.text('2 guests'), findsOneWidget);
    expect(find.text('3 nights'), findsOneWidget);
    expect(find.text('270.00 KM'), findsOneWidget);
    expect(find.text('Cleaning fee'), findsOneWidget);
    expect(find.text('285.00 KM'), findsOneWidget);
  });

  // A term carries the hour it begins rather than a pair of dates, and the
  // booking row does not hold that hour: the screen that chose it hands it on.
  testWidgets('a booked term says when it begins and how long it runs', (
    WidgetTester tester,
  ) async {
    await pushOnto(
      tester,
      BookingScreen(
        termBooking(experienceSlotId: 4),
        term: experienceSlot(
          id: 4,
          startTime: DateTime.utc(2026, 7, 14, 7),
          durationMinutes: 180,
        ),
      ),
      auth: AuthDouble(),
    );

    expect(find.text('Old town walk'), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('50.00 KM'), findsNWidgets(2));
  });

  // A hold nobody mentioned is a booking that quietly disappears.
  testWidgets('the hold is counted down and says what runs out with it', (
    WidgetTester tester,
  ) async {
    await pushOnto(
      tester,
      BookingScreen(stayBooking(heldFor: const Duration(hours: 3))),
      auth: AuthDouble(),
    );

    expect(
      find.textContaining('Held for 2 h 59 min. It is released if it has not'),
      findsOneWidget,
    );
  });

  testWidgets('a hold that has already run out says so instead', (
    WidgetTester tester,
  ) async {
    await pushOnto(
      tester,
      BookingScreen(stayBooking(heldFor: Duration.zero)),
      auth: AuthDouble(),
    );

    expect(find.text('The hold on this booking ran out.'), findsOneWidget);
  });
}
