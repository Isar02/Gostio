import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/account_tab.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/favorite_fixture.dart';
import '../../support/favorites_double.dart';
import '../../support/notifications_double.dart';
import '../../support/phone.dart';
import '../../support/review_fixture.dart';
import '../../support/reviews_double.dart';
import '../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('signing out tells the server and then ends the session', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: auth,
        session: session,
        notifications: NotificationsDouble(),
      ),
    );

    expect(find.text('Emina Begić'), findsOneWidget);
    expect(find.text('emina.b@gostio.test'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.wasSignedOut, isTrue);
    expect(session.isSignedIn, isFalse);
    expect(session.lastEnding, SessionEnding.signedOut);
  });

  // The session is this client's to end. A server that could not be told is
  // said so, and the account is signed out here regardless.
  testWidgets('a sign out the server never heard still ends the session', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(signOutFails: true);
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: auth,
        session: session,
        notifications: NotificationsDouble(),
      ),
    );

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(session.isSignedIn, isFalse);
  });

  // The profile is the second way to a review. The first is the trip it was
  // written against, and a guest who remembers the listing rather than the
  // booking would otherwise have to walk the past trips to find one.
  testWidgets('the profile opens what this account has written', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(
      written: <Review>[review(listingTitle: 'Cottage by the Pliva lakes')],
    );
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: AuthDouble(),
        session: session,
        notifications: NotificationsDouble(),
        reviews: reviews,
      ),
    );

    await tester.tap(find.text('What you have written'));
    await tester.pumpAndSettle();

    expect(find.text('Your reviews'), findsOneWidget);
    expect(find.text('Cottage by the Pliva lakes'), findsOneWidget);
  });

  // The profile is where a saved listing is looked for. The heart that put it
  // there is on the listing, and nothing else in the client gathers the two
  // catalogues into one list.
  testWidgets('the profile opens what this account has kept', (
    WidgetTester tester,
  ) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: AuthDouble(),
        session: session,
        notifications: NotificationsDouble(),
        saved: FavoritesDouble(
          kept: <Favorite>[favorite(listingTitle: 'Stone villa above Neum')],
        ),
      ),
    );

    await tester.tap(find.text('Stays and experiences you have kept'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Stone villa above Neum'), findsOneWidget);
  });
}
