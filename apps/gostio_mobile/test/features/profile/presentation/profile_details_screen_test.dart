import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_details_screen.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<Session> openDetails(
    WidgetTester tester, {
    required ProfileDouble profile,
    ProfileWriteLock? lock,
    User? holds,
  }) async {
    final User signedIn = holds ?? account();
    final Session session = signedOutSession()
      ..begin(account: signedIn, token: 'the-token');

    await pushOnto(
      tester,
      ProfileDetailsScreen(account: signedIn),
      auth: AuthDouble(),
      session: session,
      profile: profile,
      profileWrites: lock,
    );

    return session;
  }

  testWidgets('the form opens on the account as it stands', (
    WidgetTester tester,
  ) async {
    await openDetails(tester, profile: ProfileDouble());

    expect(find.widgetWithText(TextFormField, 'Emina'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Begić'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'emina.b@gostio.test'),
      findsOneWidget,
    );
  });

  // A form holding what the account already says has nothing to send, and a
  // button that has to be pressed to learn that is a button that lied.
  testWidgets('nothing changed is a button that says so', (
    WidgetTester tester,
  ) async {
    await openDetails(tester, profile: ProfileDouble());

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Emina'),
      'Emina-Sara',
    );
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('what was saved is sent, taken up and left behind', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    final Session session = await openDetails(tester, profile: profile);

    await tester.enterText(
      find.widgetWithText(TextFormField, '+38761234567'),
      '061 900 400',
    );
    await tester.pump();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(profile.saved?.phoneNumber, '061 900 400');
    expect(session.account?.phoneNumber, '061 900 400');
    expect(find.text('Your details were saved.'), findsOneWidget);
    expect(find.text('Your details'), findsNothing);
  });

  // The server faults by the property it bound, which is the name the field
  // was sent under.
  testWidgets('a refused save faults the field and stays on the form', (
    WidgetTester tester,
  ) async {
    final Session session = await openDetails(
      tester,
      profile: ProfileDouble(
        updateFailure: const ApiException(
          message: 'The request was not valid.',
          errors: <String, List<String>>{
            'email': <String>['That email is already on another account.'],
          },
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'emina.b@gostio.test'),
      'zara@gostio.test',
    );
    await tester.pump();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('That email is already on another account.'),
      findsOneWidget,
    );
    expect(find.text('Your details'), findsOneWidget);
    expect(session.account?.email, 'emina.b@gostio.test');
  });

  // A phone form is left by a gesture rather than by a button, so what is
  // typed and not saved is asked about rather than dropped.
  testWidgets('leaving with something changed asks first', (
    WidgetTester tester,
  ) async {
    await openDetails(tester, profile: ProfileDouble());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Begić'),
      'Begić-Sarić',
    );
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Leave your details?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Your details'), findsOneWidget);
  });

  // The lesson the desktop learned the hard way: one write across all three,
  // not one per button. A save that lands while a password change is out is
  // answered with a 401 that would end the session.
  testWidgets('a save while another write is out is not offered', (
    WidgetTester tester,
  ) async {
    final ProfileWriteLock lock = ProfileWriteLock();
    final Completer<bool> other = Completer<bool>();

    await openDetails(tester, profile: ProfileDouble(), lock: lock);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Emina'),
      'Emina-Sara',
    );
    await tester.pump();

    unawaited(lock.holding(() => other.future));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    other.complete(true);
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    lock.dispose();
  });
}
