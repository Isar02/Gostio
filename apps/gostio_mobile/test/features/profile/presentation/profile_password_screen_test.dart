import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_password_screen.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<Session> openPassword(
    WidgetTester tester, {
    required ProfileDouble profile,
  }) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await pushOnto(
      tester,
      const ProfilePasswordScreen(),
      auth: AuthDouble(),
      session: session,
      profile: profile,
    );

    return session;
  }

  Future<void> fillIn(
    WidgetTester tester, {
    String current = 'the-old-one',
    String next = 'the-new-one',
    String repeat = 'the-new-one',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      current,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      next,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repeat the new password'),
      repeat,
    );
    await tester.pump();
  }

  // A password that changed ends every token issued before it, this one
  // included. Signing somebody out of the phone they just proved they own
  // would be the wrong answer to the right thing happening.
  testWidgets('a changed password renews the token and keeps the session', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    final Session session = await openPassword(tester, profile: profile);
    final int before = session.tokenGeneration;

    await fillIn(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(profile.passwordSent?.currentPassword, 'the-old-one');
    expect(profile.passwordSent?.newPassword, 'the-new-one');
    expect(profile.passwordSent?.confirmNewPassword, 'the-new-one');
    expect(session.isSignedIn, isTrue);
    expect(session.tokenGeneration, greaterThan(before));
    expect(find.text('Your password was changed.'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('the password that was wrong is said on its own field', (
    WidgetTester tester,
  ) async {
    final Session session = await openPassword(
      tester,
      profile: ProfileDouble(
        passwordFailure: const ApiException(
          message: 'The request was not valid.',
          errors: <String, List<String>>{
            'currentPassword': <String>['That is not your current password.'],
          },
        ),
      ),
    );
    final int before = session.tokenGeneration;

    await fillIn(tester, current: 'not-the-old-one');
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('That is not your current password.'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(session.tokenGeneration, before);
    expect(session.isSignedIn, isTrue);
  });

  // The two are checked here so that a mistyped repeat is one keystroke to fix
  // rather than a request and a refusal.
  testWidgets('a repeat that does not match is refused before it is sent', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    await openPassword(tester, profile: profile);

    await fillIn(tester, repeat: 'the-other-one');
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('The two passwords do not match.'), findsOneWidget);
    expect(profile.passwordSent, isNull);
  });

  testWidgets('leaving with something typed asks first', (
    WidgetTester tester,
  ) async {
    await openPassword(tester, profile: ProfileDouble());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'the-old-one',
    );
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Your password has not been changed.'), findsOneWidget);
  });
}
