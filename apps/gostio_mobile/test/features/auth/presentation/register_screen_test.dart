import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/auth/data/account_registration.dart';
import 'package:gostio_mobile/features/auth/presentation/register_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('a registration opens the account already signed in', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();
    final Session session = signedOutSession();

    await pushOnto(
      tester,
      const RegisterScreen(),
      auth: auth,
      session: session,
    );

    await _fillIn(tester);
    await _create(tester);

    final AccountRegistration? sent = auth.registered;
    expect(sent?.firstName, 'Emina');
    expect(sent?.lastName, 'Begić');
    expect(sent?.username, 'emina.b');
    expect(sent?.email, 'emina.b@gostio.test');
    expect(sent?.phoneNumber, '+38761234567');
    expect(sent?.password, 'the-password');
    expect(sent?.confirmPassword, 'the-password');
    expect(session.isSignedIn, isTrue);
  });

  // The account is drawn under this route rather than over it, so a form left
  // standing would hide the thing it just opened.
  testWidgets('a registration leaves the form it was made on', (
    WidgetTester tester,
  ) async {
    await pushOnto(tester, const RegisterScreen(), auth: AuthDouble());

    await _fillIn(tester);
    await _create(tester);

    expect(find.byType(RegisterScreen), findsNothing);
  });

  // The field is optional, and an account with no number is not an account
  // with an empty one.
  testWidgets('a phone number left blank is sent as nothing', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const RegisterScreen(), auth: auth);

    await _fillIn(tester, phoneNumber: '');
    await _create(tester);

    expect(auth.registered?.phoneNumber, isNull);
  });

  testWidgets('a username the server already has is faulted on its field', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(
      failure: const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Username': <String>['An account already uses this username.'],
        },
      ),
    );

    await pushOnto(tester, const RegisterScreen(), auth: auth);

    await _fillIn(tester);
    await _create(tester);

    expect(find.text('An account already uses this username.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Username'))
          .controller
          ?.text,
      'emina.b',
    );
  });

  testWidgets('the two passwords are held to each other before they are sent', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const RegisterScreen(), auth: auth);

    await _fillIn(tester, confirmPassword: 'another-password');
    await _create(tester);

    expect(find.text('The two passwords do not match.'), findsOneWidget);
    expect(auth.registered, isNull);
  });

  testWidgets('leaving a form that still holds something asks first', (
    WidgetTester tester,
  ) async {
    await pushOnto(tester, const RegisterScreen(), auth: AuthDouble());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Emina',
    );
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Leave this form?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('a form with nothing in it is left without being asked', (
    WidgetTester tester,
  ) async {
    await pushOnto(tester, const RegisterScreen(), auth: AuthDouble());

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Leave this form?'), findsNothing);
  });
}

Future<void> _fillIn(
  WidgetTester tester, {
  String phoneNumber = '+38761234567',
  String confirmPassword = 'the-password',
}) async {
  final Map<String, String> typed = <String, String>{
    'First name': 'Emina',
    'Last name': 'Begić',
    'Username': 'emina.b',
    'Email': 'emina.b@gostio.test',
    'Phone number': phoneNumber,
    'Password': 'the-password',
    'Repeat the password': confirmPassword,
  };

  for (final MapEntry<String, String> field in typed.entries) {
    await tester.enterText(
      find.widgetWithText(TextFormField, field.key),
      field.value,
    );
  }

  await tester.pump();
}

Future<void> _create(WidgetTester tester) async {
  final Finder button = find.widgetWithText(FilledButton, 'Create account');

  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
