import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/password_draft.dart';
import '../data/profile_repository.dart';
import 'profile_write_lock.dart';
import 'session_mark.dart';

// Changing a password ends every token issued before it, the one this session
// holds included. The reply carries the replacement, so it is taken up here and
// the reader stays where they are — signing somebody out of the phone they just
// proved they own would be the wrong answer to the right thing happening.
//
// It is taken up only where the session is still the one that asked. A change
// begun by one account can land after the phone has been signed out and signed
// in as another, and adopting the first account's token into the second
// account's session would sign the second reader in as somebody else with
// nothing on the screen to say so.
class ProfilePasswordNotifier extends ScreenNotifier {
  ProfilePasswordNotifier(this._profile, this._session, this._lock);

  final ProfileRepository _profile;
  final Session _session;
  final ProfileWriteLock _lock;

  Future<bool> change(PasswordDraft draft) => _lock.holding(() {
    final SessionMark mark = SessionMark.of(_session);

    return performRequest(
      () => _profile.changePassword(
        draft,
        adopt: (String token) {
          if (mark.stillHolds(_session)) {
            _session.tokenRenewed(token);
          }
        },
      ),
    );
  });
}
