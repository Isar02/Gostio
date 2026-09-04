import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_client.dart';
import 'package:gostio_desktop/core/session/session.dart';
import 'package:gostio_desktop/features/profile/presentation/profile_notifier.dart';
import 'package:gostio_desktop/features/users/data/user_draft.dart';

import '../../../support/account_fixture.dart';
import '../../../support/profile_double.dart';

void main() {
  // The session's copy was answered when the token was issued, and an
  // administrator may have edited the account since. The screen reads the
  // account anyway, so the read is the cheapest moment to stop the top bar
  // being older than the screen under it.
  test('reading the account brings the session up to date with it', () async {
    final Session session = _session();
    final ProfileNotifier notifier = ProfileNotifier(
      ProfileDouble(
        mine: account(firstName: 'Amila', lastName: 'Selimović'),
      ),
      session,
    );

    await notifier.load();

    expect(session.account?.fullName, 'Amila Selimović');
  });

  // Two writes overlapping is not a slow screen but a wrong one: a password
  // that lands while a save is in flight raises the token version, and the
  // save already on its way is answered with a 401 that ends the session.
  test('a second write is refused while the first is still out', () async {
    final ProfileDouble profile = ProfileDouble(holdsTheWrite: true);
    final ProfileNotifier notifier = ProfileNotifier(profile, _session());

    await notifier.load();

    final Future<bool> saving = notifier.saveDetails(_draft);

    expect(notifier.isWriting, isTrue);

    final bool changed = await notifier.changePassword(
      currentPassword: 'the-old-one',
      newPassword: 'a-longer-new-one',
      confirmNewPassword: 'a-longer-new-one',
    );

    expect(changed, isFalse);
    expect(profile.currentPasswordSent, isNull);

    profile.releaseTheWrite();

    expect(await saving, isTrue);
    expect(notifier.isWriting, isFalse);
  });

  // The refusal is not a failure the screen has to say anything about: the
  // button that would have started it was disabled, so nothing was refused
  // that anybody asked for.
  test('a write held off leaves no failure behind it', () async {
    final ProfileDouble profile = ProfileDouble(holdsTheWrite: true);
    final ProfileNotifier notifier = ProfileNotifier(profile, _session());

    await notifier.load();

    final Future<bool> saving = notifier.saveDetails(_draft);

    await notifier.changePassword(
      currentPassword: 'the-old-one',
      newPassword: 'a-longer-new-one',
      confirmNewPassword: 'a-longer-new-one',
    );

    expect(notifier.passwordFailureMessage, isNull);

    profile.releaseTheWrite();
    await saving;
  });
}

const UserDraft _draft = UserDraft(
  firstName: 'Amila',
  lastName: 'Selimović',
  email: 'amila@gostio.test',
  phoneNumber: null,
);

Session _session() =>
    Session(ApiClient(baseUrl: Uri.parse('http://localhost:5000')))
      ..begin(account: account(), token: 'the-token-it-signed-in-with');
