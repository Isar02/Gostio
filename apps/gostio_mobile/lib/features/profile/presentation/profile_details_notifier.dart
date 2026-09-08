import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/profile_draft.dart';
import '../data/profile_repository.dart';
import 'profile_write_lock.dart';

// The four fields, saved as one. What comes back is the account itself, so it
// goes to the session and the name over the profile is the name that was just
// written rather than the one this screen opened on — as long as the session it
// goes to is still the one that asked.
class ProfileDetailsNotifier extends ScreenNotifier {
  ProfileDetailsNotifier(this._profile, this._session, this._lock);

  final ProfileRepository _profile;
  final Session _session;
  final ProfileWriteLock _lock;

  Future<bool> save(ProfileDraft draft) => _lock.holding(() {
    final SessionMark mark = SessionMark.of(_session);

    return performRequest(() async {
      final User written = await _profile.update(draft);

      if (mark.stillHolds(_session)) {
        _session.accountChanged(written);
      }
    });
  });
}
