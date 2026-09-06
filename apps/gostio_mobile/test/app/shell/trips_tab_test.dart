import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/trips_tab.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/booking_fixture.dart';
import '../../support/notifications_double.dart';
import '../../support/payment_double.dart';
import '../../support/phone.dart';
import '../../support/reviews_double.dart';
import '../../support/screens.dart';
import '../../support/trips_double.dart';

// The tab is where the application composes the two features that meet on a
// finished booking. Trips draws the booking and reviews draws what was said
// about it, and neither reaches into the other, so the composition itself is
// what has to be held: a trip opened without it is a screen that has quietly
// lost its review section.
void main() {
  setUp(usePhoneScreen);

  testWidgets('a finished trip opened from the tab carries its review', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble();
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const TripsTab(),
        auth: AuthDouble(),
        session: session,
        notifications: NotificationsDouble(),
        payments: PaymentDouble(),
        cardSheet: CardSheetDouble(),
        trips: TripsDouble(
          past: <Reservation>[
            stayBooking(standing: ReservationStatus.completed, isPaid: true),
          ],
        ),
        reviews: reviews,
      ),
    );

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loft over the river'));
    await tester.pumpAndSettle();

    expect(find.text('Your review'), findsOneWidget);
    expect(reviews.read, <int>[501]);
  });
}
