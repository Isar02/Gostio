import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/session_check.dart';

import '../support/account_fixture.dart';
import '../support/auth_double.dart';
import '../support/phone.dart';
import '../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('coming back to the foreground asks who is signed in', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(user: account(firstName: 'Vedran'));
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await _pump(tester, auth: auth, session: session);
    await _comeBack(tester);

    expect(auth.meCalls, 1);
    expect(session.account?.firstName, 'Vedran');
  });

  testWidgets('nobody signed in is nobody to ask about', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await _pump(tester, auth: auth, session: signedOutSession());
    await _comeBack(tester);

    expect(auth.meCalls, 0);
  });

  // A phone comes back to the foreground in places with no signal. The session
  // ends on a refusal, which the client raises, and on nothing else.
  testWidgets('an unreachable API does not end the session', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(
      failure: const ApiException(message: 'The API could not be reached.'),
    );
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await _pump(tester, auth: auth, session: session);
    await _comeBack(tester);

    expect(session.isSignedIn, isTrue);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required AuthDouble auth,
  required Session session,
}) => tester.pumpWidget(
  underTest(
    const SessionCheck(child: Scaffold()),
    auth: auth,
    session: session,
  ),
);

Future<void> _comeBack(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  await tester.pumpAndSettle();
}
