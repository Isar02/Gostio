import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/auth/presentation/reset_password_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  // The reset issues no token, so what it leaves behind is a screen to sign
  // in on and a sentence saying why.
  testWidgets('a reset sends the code and hands back the sign in screen', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const ResetPasswordScreen(), auth: auth);

    await _fillIn(tester, code: ' A1B2C3 ');
    await _change(tester);

    expect(auth.codeSent, 'A1B2C3');
    expect(auth.newPasswordSent, 'the-new-password');
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(
      find.text('Your password was changed. Sign in with it.'),
      findsOneWidget,
    );
  });

  testWidgets('a code the server will not spend is faulted on its field', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(
      failure: const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Token': <String>['This code is no longer valid. Ask for a new one.'],
        },
      ),
    );

    await pushOnto(tester, const ResetPasswordScreen(), auth: auth);

    await _fillIn(tester);
    await _change(tester);

    expect(
      find.text('This code is no longer valid. Ask for a new one.'),
      findsOneWidget,
    );
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });

  testWidgets('a password shorter than the server takes is refused here', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await pushOnto(tester, const ResetPasswordScreen(), auth: auth);

    await _fillIn(tester, newPassword: 'short');
    await _change(tester);

    expect(
      find.text('A password is at least 8 characters long.'),
      findsOneWidget,
    );
    expect(auth.codeSent, isNull);
  });
}

Future<void> _fillIn(
  WidgetTester tester, {
  String code = 'A1B2C3',
  String newPassword = 'the-new-password',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Code'), code);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'New password'),
    newPassword,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Repeat the new password'),
    newPassword,
  );
  await tester.pump();
}

Future<void> _change(WidgetTester tester) async {
  final Finder button = find.widgetWithText(FilledButton, 'Change password');

  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
