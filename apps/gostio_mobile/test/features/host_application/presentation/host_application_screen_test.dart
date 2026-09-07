import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/host_application/presentation/host_application_screen.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/host_application_double.dart';
import '../../../support/host_application_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    HostApplicationDouble applications, {
    List<String> roles = const <String>['Guest'],
  }) async {
    await pushOnto(
      tester,
      const HostApplicationScreen(),
      auth: AuthDouble(),
      session: signedOutSession()
        ..begin(
          account: account(roles: roles),
          token: 'the-token',
        ),
      hostApplications: applications,
    );
  }

  testWidgets('an account that has never applied is invited and may apply', (
    WidgetTester tester,
  ) async {
    final HostApplicationDouble applications = HostApplicationDouble();

    await open(tester, applications);

    expect(find.text('Put your own place on Gostio'), findsOneWidget);
    // What is sent is what an administrator reads, and it is the account
    // itself rather than anything typed in here.
    expect(find.text('Emina Begić'), findsOneWidget);
    expect(find.text('emina.b'), findsOneWidget);

    await tester.tap(find.text('Send your application'));
    await tester.pumpAndSettle();

    expect(applications.applications, 1);
    expect(find.text('Your application was sent.'), findsOneWidget);
    expect(find.text('Waiting for an answer'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);
  });

  // One application waits at a time. Offering a second is offering a refusal.
  testWidgets('an application already waiting offers nothing to press', (
    WidgetTester tester,
  ) async {
    await open(tester, HostApplicationDouble(holds: hostApplication()));

    expect(find.text('Your application is being read'), findsOneWidget);
    expect(find.text('Waiting for an answer'), findsOneWidget);
    expect(find.text('30 Aug 2026'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);
  });

  // The reason is the whole of what a reader who was turned down came for, and
  // applying again is what the server itself invites.
  testWidgets('a rejection carries its reason and another go', (
    WidgetTester tester,
  ) async {
    final HostApplicationDouble applications = HostApplicationDouble(
      holds: turnedDown(),
    );

    await open(tester, applications);

    expect(find.text('Your application was turned down'), findsOneWidget);
    expect(find.text('Turned down'), findsOneWidget);
    expect(find.text('The uploaded document was unreadable.'), findsOneWidget);

    await tester.tap(find.text('Send your application'));
    await tester.pumpAndSettle();

    expect(applications.applications, 1);
  });

  // The one role this client reads. An account that already hosts is told
  // where hosting is done rather than invited to ask for it again.
  testWidgets('an account that already hosts is told so and offered nothing', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      HostApplicationDouble(holds: approved()),
      roles: <String>['Guest', 'Host'],
    );

    expect(find.text('You host on Gostio'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Hosting on Gostio'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);
  });

  // Approved without the role is the moment between the two: the account was
  // granted hosting and the token this phone holds was issued before that.
  testWidgets('an approval this token predates asks for a fresh sign in', (
    WidgetTester tester,
  ) async {
    await open(tester, HostApplicationDouble(holds: approved()));

    expect(find.text('Your application was approved'), findsOneWidget);
    expect(find.textContaining('Sign in again'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);
  });

  // A standing this build does not know is the server's word, drawn as the
  // server's word. Nothing here guesses what it means, and nothing is offered
  // over it.
  testWidgets('a standing this build does not know is left as it came', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      HostApplicationDouble(holds: hostApplication(status: 'Withdrawn')),
    );

    expect(find.text('Your application'), findsOneWidget);
    expect(find.text('Withdrawn'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);
  });

  testWidgets('a refused first read is the error state and reads again', (
    WidgetTester tester,
  ) async {
    final _RefusingFirstRead applications = _RefusingFirstRead();

    await open(tester, applications);

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Send your application'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Put your own place on Gostio'), findsOneWidget);
  });

  // A refusal has no field of its own to sit under, so it is said where the
  // button was, and the reader stays on the screen that asked.
  testWidgets('a refused application is said on the screen that asked', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      HostApplicationDouble(
        applyFailure: const ApiException(
          message: 'This account already hosts on Gostio.',
          statusCode: 400,
        ),
      ),
    );

    await tester.tap(find.text('Send your application'));
    await tester.pumpAndSettle();

    expect(find.text('This account already hosts on Gostio.'), findsOneWidget);
    expect(find.text('Put your own place on Gostio'), findsOneWidget);
    expect(find.byType(HostApplicationScreen), findsOneWidget);
  });
}

// Refuses the read the screen opens with and answers the one behind the
// button under it.
class _RefusingFirstRead extends HostApplicationDouble {
  @override
  Future<HostApplication?> mine() async {
    reads++;

    if (reads == 1) {
      throw const ApiException(
        message: 'The API could not be reached.',
        statusCode: 503,
      );
    }

    return null;
  }
}
