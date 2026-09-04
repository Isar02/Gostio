import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/profile/data/profile_repository.dart';
import 'package:gostio_desktop/features/profile/presentation/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/account_fixture.dart';
import '../../../support/profile_double.dart';

// Two forms side by side, at the width the client is drawn for.
const Size _window = Size(1440, 900);

void main() {
  setUp(() {
    final TestFlutterView view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;

    view.physicalSize = _window;
    view.devicePixelRatio = 1;

    addTearDown(view.reset);
  });

  // What the session is holding was answered when the token was issued and
  // may be old by now, so the screen asks rather than drawing what it has.
  testWidgets('the account is read from the server rather than the session', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(
      mine: account(firstName: 'Amila', lastName: 'Selimović'),
    );

    await tester.pumpWidget(_screen(profile));
    await tester.pumpAndSettle();

    expect(find.text('Amila Selimović'), findsOneWidget);
    expect(find.text('lamija.h'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
  });

  testWidgets('a save writes the four fields and the shell sees the new name', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    final Session session = _session();

    await tester.pumpWidget(_screen(profile, session: session));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Amila',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(profile.updated?.firstName, 'Amila');
    expect(profile.updated?.email, 'lamija.h@gostio.test');
    expect(session.account?.firstName, 'Amila');
    expect(find.text('Your details were saved.'), findsOneWidget);
  });

  testWidgets('a refused save keeps what was typed and faults the field', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(updateFails: true);

    await tester.pumpWidget(_screen(profile));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'taken@gostio.test',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('An account already uses this address.'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'taken@gostio.test'),
      findsOneWidget,
    );
  });

  // The three writes have three endpoints but one account behind them, and
  // the password one ends every token issued before it. While any of them is
  // out, none of the others may be started.
  testWidgets('a save in flight holds every other write on the screen', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(holdsTheWrite: true);

    await tester.pumpWidget(_screen(profile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(_enabled<FilledButton>(tester, 'Saving'), isFalse);
    expect(_enabled<FilledButton>(tester, 'Change password'), isFalse);
    expect(_enabled<OutlinedButton>(tester, 'Choose a picture'), isFalse);

    profile.releaseTheWrite();
    await tester.pumpAndSettle();

    expect(_enabled<FilledButton>(tester, 'Save changes'), isTrue);
    expect(_enabled<FilledButton>(tester, 'Change password'), isTrue);
    expect(_enabled<OutlinedButton>(tester, 'Choose a picture'), isTrue);
  });

  testWidgets('nothing is written until the three password fields hold', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();

    await tester.pumpWidget(_screen(profile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(profile.currentPasswordSent, isNull);
    expect(find.text('Enter your current password.'), findsOneWidget);
    expect(find.text('Enter a new password.'), findsOneWidget);
    expect(find.text('Repeat the new password.'), findsOneWidget);
  });

  // The server raises the account's token version on this call, so every token
  // it issued before now is refused — the one this window is holding included.
  // Taking up the replacement is what keeps the next call from being a 401.
  testWidgets('a changed password takes up the token the answer carries', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    final ApiClient client = _client();
    final Session session = _session(client: client);

    await tester.pumpWidget(_screen(profile, session: session, client: client));
    await tester.pumpAndSettle();

    await _typeThePasswords(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(profile.currentPasswordSent, 'the-old-one');
    expect(profile.newPasswordSent, 'a-longer-new-one');
    expect(client.token, 'the-token-after-the-change');
    expect(session.isSignedIn, isTrue);
    expect(find.text('Your password was changed.'), findsOneWidget);
  });

  testWidgets('a changed password leaves none of the three on the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ProfileDouble()));
    await tester.pumpAndSettle();

    await _typeThePasswords(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('the-old-one'), findsNothing);
    expect(find.text('a-longer-new-one'), findsNothing);
  });

  testWidgets('a wrong current password is said under the field it is about', (
    WidgetTester tester,
  ) async {
    final ApiClient client = _client();

    await tester.pumpWidget(
      _screen(
        ProfileDouble(passwordFails: true),
        session: _session(client: client),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await _typeThePasswords(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('This is not your current password.'), findsOneWidget);
    expect(client.token, 'the-token-it-signed-in-with');
  });
}

bool _enabled<T extends ButtonStyleButton>(WidgetTester tester, String label) =>
    tester.widget<T>(find.widgetWithText(T, label)).enabled;

Future<void> _typeThePasswords(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Current password'),
    'the-old-one',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'New password'),
    'a-longer-new-one',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Repeat the new password'),
    'a-longer-new-one',
  );
}

ApiClient _client() => ApiClient(baseUrl: Uri.parse('http://localhost:5000'));

Session _session({ApiClient? client}) =>
    Session(client ?? _client())
      ..begin(account: account(), token: 'the-token-it-signed-in-with');

Widget _screen(ProfileDouble profile, {Session? session, ApiClient? client}) {
  final ApiClient reached = client ?? _client();

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ApiClient>.value(value: reached),
      ChangeNotifierProvider<Session>.value(
        value: session ?? _session(client: reached),
      ),
      Provider<ProfileRepository>.value(value: profile),
    ],
    child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
  );
}
