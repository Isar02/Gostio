import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/account_tab.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/favorite_fixture.dart';
import '../../support/favorites_double.dart';
import '../../support/host_application_double.dart';
import '../../support/host_application_fixture.dart';
import '../../support/notifications_double.dart';
import '../../support/phone.dart';
import '../../support/profile_double.dart';
import '../../support/push_double.dart';
import '../../support/review_fixture.dart';
import '../../support/reviews_double.dart';
import '../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  // The profile is longer than a phone, so what is being pressed is brought
  // into view first — the same thing a thumb does before it presses anything.
  Future<void> reach(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 200);
    await tester.pumpAndSettle();
  }

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

    await reach(tester, 'Sign out');
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

    await reach(tester, 'Sign out');
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

    await reach(tester, 'What you have written');
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

    await reach(tester, 'Stays and experiences you have kept');
    await tester.tap(find.text('Stays and experiences you have kept'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Stone villa above Neum'), findsOneWidget);
  });

  // The one row in this client whose words come off a role. A guest is invited
  // and a host is told where hosting is done, and both open the same screen.
  testWidgets('the profile names hosting by what this account may do', (
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
        hostApplications: HostApplicationDouble(),
      ),
    );

    await reach(tester, 'Become a host');
    await tester.tap(find.text('Become a host'));
    await tester.pumpAndSettle();

    expect(find.text('Put your own place on Gostio'), findsOneWidget);
  });

  testWidgets('an account that hosts reads the row as what it already is', (
    WidgetTester tester,
  ) async {
    final User hosting = account(roles: <String>['Guest', 'Host']);
    final Session session = signedOutSession()
      ..begin(account: hosting, token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: AuthDouble(),
        session: session,
        notifications: NotificationsDouble(),
        // The profile reads the account again as it opens, so the answer
        // behind that read is the one the row is named from.
        profile: ProfileDouble(holds: hosting),
        hostApplications: HostApplicationDouble(holds: approved()),
      ),
    );

    await reach(tester, 'Hosting on Gostio');
    await tester.tap(find.text('Hosting on Gostio'));
    await tester.pumpAndSettle();

    expect(find.text('You host on Gostio'), findsOneWidget);
  });

  // A phone is handed between people. A registration left behind delivers this
  // account's bookings to whoever holds the phone next, and the call that
  // removes it is made with this account's token — so it happens before the
  // session ends rather than after it.
  testWidgets('signing out gives up the device before it ends the session', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushMessagingDouble messaging = PushMessagingDouble(
      token: 'device-token',
    );
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AccountTab(),
        auth: AuthDouble(),
        session: session,
        notifications: notifications,
        messaging: messaging,
      ),
    );
    await tester.pumpAndSettle();

    expect(notifications.registered, <String>['device-token']);

    await reach(tester, 'Sign out');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(notifications.forgotten, <String>['device-token']);
    expect(session.isSignedIn, isFalse);

    await messaging.close();
  });

  // A sign-out the reader pressed is not one to abandon halfway. Everything
  // the session needs is read before the device is given up, so a screen that
  // goes while that call is still out cannot leave the account signed in.
  testWidgets(
    'a screen that goes while the device is given up still signs out',
    (WidgetTester tester) async {
      final _HeldRemoval notifications = _HeldRemoval();
      final PushMessagingDouble messaging = PushMessagingDouble(
        token: 'device-token',
      );
      final Session session = signedOutSession()
        ..begin(account: account(), token: 'the-token');

      await tester.pumpWidget(
        underTest(
          const AccountTab(),
          auth: AuthDouble(),
          session: session,
          notifications: notifications,
          messaging: messaging,
        ),
      );
      await tester.pumpAndSettle();

      await reach(tester, 'Sign out');
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await notifications.reached;

      // The screen the reader pressed the button on is gone before the removal
      // has been answered.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      notifications.answer();
      await tester.pumpAndSettle();

      expect(session.isSignedIn, isFalse);
      expect(session.lastEnding, SessionEnding.signedOut);

      await messaging.close();
    },
  );
}

// Holds the removal until a test says the server answered, which is what lets
// the screen that asked for it go while the call is still out.
class _HeldRemoval extends NotificationsDouble {
  final Completer<void> _reached = Completer<void>();
  final Completer<void> _answer = Completer<void>();

  Future<void> get reached => _reached.future;

  void answer() => _answer.complete();

  @override
  Future<void> forgetDevice(String token) async {
    if (!_reached.isCompleted) {
      _reached.complete();
    }

    await _answer.future;
    await super.forgetDevice(token);
  }
}
