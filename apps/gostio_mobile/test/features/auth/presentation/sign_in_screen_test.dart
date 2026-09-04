import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:gostio_mobile/features/auth/presentation/register_screen.dart';
import 'package:gostio_mobile/features/auth/presentation/sign_in_screen.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('a sign in begins the session on what the API answered', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(user: account(firstName: 'Vedran'));
    final Session session = signedOutSession();

    await tester.pumpWidget(
      underTest(const SignInScreen(), auth: auth, session: session),
    );

    await _fillIn(tester, username: 'emina.b', password: 'the-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.usernameSent, 'emina.b');
    expect(auth.passwordSent, 'the-password');
    expect(session.isSignedIn, isTrue);
    expect(session.account?.firstName, 'Vedran');
  });

  // The whitespace a phone keyboard adds after a word is not part of a
  // username, and the server would refuse it as one.
  testWidgets('a username is sent without what was typed around it', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await tester.pumpWidget(underTest(const SignInScreen(), auth: auth));

    await _fillIn(tester, username: '  emina.b ', password: ' keeps spaces ');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.usernameSent, 'emina.b');
    expect(auth.passwordSent, ' keeps spaces ');
  });

  testWidgets('a refused sign in names the field and holds the session shut', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(
      failure: const ApiException(
        message: 'The username or password is wrong.',
        statusCode: 401,
        errors: <String, List<String>>{
          'Username': <String>['No account uses this username.'],
        },
      ),
    );
    final Session session = signedOutSession();

    await tester.pumpWidget(
      underTest(const SignInScreen(), auth: auth, session: session),
    );

    await _fillIn(tester, username: 'nobody', password: 'the-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('The username or password is wrong.'), findsOneWidget);
    expect(find.text('No account uses this username.'), findsOneWidget);
    expect(session.isSignedIn, isFalse);
  });

  testWidgets('editing a server-faulted field removes its stale refusal', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(
      failure: const ApiException(
        message: 'The username or password is wrong.',
        statusCode: 401,
        errors: <String, List<String>>{
          'Username': <String>['No account uses this username.'],
        },
      ),
    );
    await tester.pumpWidget(underTest(const SignInScreen(), auth: auth));

    await _fillIn(tester, username: 'nobody', password: 'the-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('No account uses this username.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'emina.b',
    );
    await tester.pumpAndSettle();

    expect(find.text('No account uses this username.'), findsNothing);
  });

  testWidgets('what the form can refuse itself is never sent', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble();

    await tester.pumpWidget(underTest(const SignInScreen(), auth: auth));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.usernameSent, isNull);
  });

  // The refusal is shown for as long as it is true and no longer, which a form
  // that only validates on submission cannot manage.
  testWidgets('a field put right after a refusal stops saying it is wrong', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      underTest(const SignInScreen(), auth: AuthDouble()),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your username.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'emina.b',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter your username.'), findsNothing);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('a sign in that is out says so and takes nothing else', (
    WidgetTester tester,
  ) async {
    final AuthDouble auth = AuthDouble(holdsTheCall: true);

    await tester.pumpWidget(underTest(const SignInScreen(), auth: auth));

    await _fillIn(tester, username: 'emina.b', password: 'the-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Signing in'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    auth.answer();
    await tester.pumpAndSettle();
  });

  // A token that died is not a wrong password, and the screen that is reached
  // by it says which of the two it was.
  testWidgets('a session the server ended is named on the way back in', (
    WidgetTester tester,
  ) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token')
      ..end(SessionEnding.tokenDied);

    await tester.pumpWidget(
      underTest(const SignInScreen(), auth: AuthDouble(), session: session),
    );

    expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
  });

  testWidgets('the two ways out of the screen open the forms they name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      underTest(const SignInScreen(), auth: AuthDouble()),
    );

    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}

Future<void> _fillIn(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    username,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
}
