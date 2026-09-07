import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/named_trip_screen.dart';

import '../support/auth_double.dart';
import '../support/booking_fixture.dart';
import '../support/payment_double.dart';
import '../support/phone.dart';
import '../support/reviews_double.dart';
import '../support/screens.dart';
import '../support/trips_double.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(WidgetTester tester, TripsDouble trips) async {
    await tester.pumpWidget(
      underTest(
        const NamedTripScreen(314),
        auth: AuthDouble(),
        trips: trips,
        reviews: ReviewsDouble(),
        payments: PaymentDouble(),
        cardSheet: CardSheetDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A notice carries an id and nothing else about the booking, so the row is
  // read here before the trip can be drawn.
  testWidgets('the booking a notice names is read by its id', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = TripsDouble(named: stayBooking());
    await open(tester, trips);

    expect(trips.readById, <int>[314]);
    expect(find.text('Loft over the river'), findsWidgets);
  });

  // A booking outside this account answers 404 like a missing one, which is
  // the server's rule and not a case this screen tells apart.
  testWidgets('a refused read is said in the server words with another go', (
    WidgetTester tester,
  ) async {
    final TripsDouble trips = TripsDouble(
      namedFailure: const ApiException(
        message: 'That booking could not be found.',
        traceId: '00-abc-def-01',
      ),
    );
    await open(tester, trips);

    expect(find.text('That booking could not be found.'), findsOneWidget);
    expect(find.text('Trace 00-abc-def-01'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(trips.readById, <int>[314, 314]);
  });
}
