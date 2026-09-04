import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:gostio_mobile/features/auth/presentation/reset_password_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  // The API accepts the request whether or not the address is on an account,
  // and the screen is not allowed to be more specific than the API.
  testWidgets('asking for a code says what was asked, not what was found', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const ForgotPasswordScreen(), auth: auth);

    await _ask(tester, 'emina.b@gostio.test');

    expect(auth.addressAsked, 'emina.b@gostio.test');
    expect(
      find.textContaining('If an account is registered to that address'),
      findsOneWidget,
    );
  });

  testWidgets('an address that is not one never leaves the client', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const ForgotPasswordScreen(), auth: auth);

    await _ask(tester, 'emina.b');

    expect(find.text('This is not an email address.'), findsOneWidget);
    expect(auth.addressAsked, isNull);
  });

  testWidgets('the code goes on the screen the confirmation opens', (
    WidgetTester tester,
  ) async {
    await pushOnto(tester, const ForgotPasswordScreen(), auth: AuthDouble());

    await _ask(tester, 'emina.b@gostio.test');

    await tester.tap(find.widgetWithText(FilledButton, 'Enter the code'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });

  testWidgets('a code can be asked for a second time', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const ForgotPasswordScreen(), auth: auth);

    await _ask(tester, 'emina.b@gostio.test');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'second.address@gostio.test',
    );
    await tester.tap(find.text('Send it again'));
    await tester.pumpAndSettle();

    expect(auth.addressAsked, 'second.address@gostio.test');
  });
}

Future<void> _ask(WidgetTester tester, String address) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), address);
  await tester.tap(find.widgetWithText(FilledButton, 'Send the code'));
  await tester.pumpAndSettle();
}
