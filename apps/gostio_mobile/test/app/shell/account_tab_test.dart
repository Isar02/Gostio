import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/account_tab.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/phone.dart';
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
      underTest(const AccountTab(), auth: auth, session: session),
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
      underTest(const AccountTab(), auth: auth, session: session),
    );

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(session.isSignedIn, isFalse);
  });
}
