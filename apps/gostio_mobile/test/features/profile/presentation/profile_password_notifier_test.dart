import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/password_draft.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_password_notifier.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';

import '../../../support/account_fixture.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

const PasswordDraft _draft = PasswordDraft(
  currentPassword: 'the-old-one',
  newPassword: 'the-new-one',
  confirmNewPassword: 'the-new-one',
);

void main() {
  // A session that ends empties the picture cache, which is the framework's
  // rather than this client's.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient client;
  late Session session;
  late ProfileWriteLock lock;

  setUp(() {
    client = testClient();
    session = Session(client)..begin(account: account(), token: 'the-token');
    lock = ProfileWriteLock();
  });

  tearDown(() {
    session.dispose();
    lock.dispose();
    client.close();
  });

  test('the replacement token is taken up by the session', () async {
    final ProfileDouble profile = ProfileDouble(renewedToken: 'the-new-token');
    final ProfilePasswordNotifier notifier = ProfilePasswordNotifier(
      profile,
      session,
      lock,
    );

    expect(await notifier.change(_draft), isTrue);

    expect(profile.passwordSent?.newPassword, 'the-new-one');
    expect(client.token, 'the-new-token');
    expect(session.isSignedIn, isTrue);

    notifier.dispose();
  });

  // The worst thing this feature can do. A change begun by one account can land
  // after the phone has been signed out and signed in as another, and adopting
  // the first account's token into the second account's session would sign the
  // second reader in as somebody else with nothing on the screen to say so.
  test('a change that lands in another reader session is dropped', () async {
    final Completer<void> held = Completer<void>();
    final ProfilePasswordNotifier notifier = ProfilePasswordNotifier(
      ProfileDouble(holdsWrites: held, renewedToken: 'the-first-token'),
      session,
      lock,
    );

    final Future<bool> changing = notifier.change(_draft);
    await pumpEventQueue();

    session
      ..end(SessionEnding.signedOut)
      ..begin(
        account: account(id: 33, username: 'other'),
        token: 'b-token',
      );

    held.complete();
    await changing;

    expect(client.token, 'b-token');
    expect(session.account?.id, 33);

    notifier.dispose();
  });

  // The same reply arriving after this session simply ended has nowhere to go
  // either: the token it carries belongs to an account nobody is signed in as.
  test('a change that lands after the session ended is dropped', () async {
    final Completer<void> held = Completer<void>();
    final ProfilePasswordNotifier notifier = ProfilePasswordNotifier(
      ProfileDouble(holdsWrites: held, renewedToken: 'the-new-token'),
      session,
      lock,
    );

    final Future<bool> changing = notifier.change(_draft);
    await pumpEventQueue();

    session.end(SessionEnding.signedOut);

    held.complete();
    await changing;

    expect(client.token, isNull);
    expect(session.isSignedIn, isFalse);

    notifier.dispose();
  });

  test('a refused change leaves the token this session holds', () async {
    final ProfilePasswordNotifier notifier = ProfilePasswordNotifier(
      ProfileDouble(
        passwordFailure: const ApiException(
          message: 'That is not your current password.',
        ),
      ),
      session,
      lock,
    );

    expect(await notifier.change(_draft), isFalse);

    expect(client.token, 'the-token');
    expect(notifier.failure?.message, 'That is not your current password.');

    notifier.dispose();
  });
}
