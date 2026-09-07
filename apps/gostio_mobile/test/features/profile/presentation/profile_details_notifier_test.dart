import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/profile_draft.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_details_notifier.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';

import '../../../support/account_fixture.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

const ProfileDraft _draft = ProfileDraft(
  firstName: 'Emina-Sara',
  lastName: 'Begić',
  email: 'emina.b@gostio.test',
  phoneNumber: '061 900 400',
);

void main() {
  // A session that ends empties the picture cache, which is the framework's
  // rather than this client's.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Session session;
  late ProfileWriteLock lock;

  setUp(() {
    session = signedOutSession()..begin(account: account(), token: 'the-token');
    lock = ProfileWriteLock();
  });

  tearDown(() {
    session.dispose();
    lock.dispose();
  });

  test('what was saved is what the session holds afterwards', () async {
    final ProfileDouble profile = ProfileDouble();
    final ProfileDetailsNotifier notifier = ProfileDetailsNotifier(
      profile,
      session,
      lock,
    );

    expect(await notifier.save(_draft), isTrue);

    expect(profile.saved?.firstName, 'Emina-Sara');
    expect(session.account?.firstName, 'Emina-Sara');

    notifier.dispose();
  });

  // A save begun by one account can land after the phone has been signed out
  // and signed in as another. Writing what it answers into the session would
  // put one reader's name and email on another reader's profile.
  test('a save that lands in another reader session is dropped', () async {
    final Completer<void> held = Completer<void>();
    final ProfileDetailsNotifier notifier = ProfileDetailsNotifier(
      ProfileDouble(holdsWrites: held),
      session,
      lock,
    );

    final Future<bool> saving = notifier.save(_draft);
    await pumpEventQueue();

    session
      ..end(SessionEnding.signedOut)
      ..begin(
        account: account(id: 33, firstName: 'Lejla', username: 'other'),
        token: 'b-token',
      );

    held.complete();
    await saving;

    expect(session.account?.id, 33);
    expect(session.account?.firstName, 'Lejla');

    notifier.dispose();
  });

  test('a refused save leaves the account the session holds', () async {
    final ProfileDetailsNotifier notifier = ProfileDetailsNotifier(
      ProfileDouble(
        updateFailure: const ApiException(
          message: 'That email is already on another account.',
        ),
      ),
      session,
      lock,
    );

    expect(await notifier.save(_draft), isFalse);

    expect(session.account?.firstName, 'Emina');
    expect(
      notifier.failure?.message,
      'That email is already on another account.',
    );

    notifier.dispose();
  });
}
