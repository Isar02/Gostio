import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/picture_source.dart';
import '../data/profile_repository.dart';
import 'profile_write_lock.dart';
import 'session_mark.dart';

// The profile's own two jobs: keeping the account the whole client draws from
// current, and the picture, which is the one thing written on this screen
// rather than on a form pushed from it.
//
// Nothing here holds an account of its own. What is signed in is the session's
// answer and every screen in this client already asks it, so a write that
// landed goes there rather than into a second copy this screen would then have
// to keep agreeing with.
class ProfileNotifier extends LiveNotifier {
  ProfileNotifier(this._profile, this._pictures, this._session, this._lock);

  final ProfileRepository _profile;
  final PictureSource _pictures;
  final Session _session;
  final ProfileWriteLock _lock;

  bool _isRefreshing = false;
  ApiException? _refreshFailure;

  bool _isSavingPicture = false;

  ApiException? _pictureFailure;
  String? _pictureRefusal;

  // Whether this write is the one out, rather than whether any of the three
  // is: the lock says what the control may do, and this says what it says.
  bool get isSavingPicture => _isSavingPicture;

  bool get isRefreshing => _isRefreshing;

  // The message alone, which is what a refusal that blocks nothing is drawn as
  // here: the account is still on the screen, and the trace id belongs to the
  // state that has room for it.
  String? get refreshFailureMessage => _refreshFailure?.message;

  // One line under the picture, whatever refused it. The file has no field of
  // its own on the screen to fault, so the sentence about the file is preferred
  // over the summary standing over it.
  String? get pictureMessage =>
      _pictureRefusal ??
      _pictureFailure?.firstMessageFor(ProfileRepository.fileField) ??
      _pictureFailure?.message;

  // The account was read when the token was issued, which on this client may
  // have been days ago: an administrator may have edited it since, and a host
  // application approved since is a role this account did not have then.
  Future<void> refresh() async {
    // A pull while the read this screen opened with is still out would be a
    // second answer to the same question, and the later one to land would win
    // rather than the newer one.
    // The write will put the account the server answered into the session. A
    // read begun while that write is still out can only answer the account as
    // it stood before the write, and may arrive after it. There is therefore
    // nothing useful for a concurrent refresh to do.
    if (_isRefreshing || _lock.isWriting) {
      return;
    }

    _isRefreshing = true;
    _refreshFailure = null;
    publish();

    final SessionMark mark = SessionMark.of(_session);
    final int writesBefore = _lock.writes;

    try {
      final User read = await _profile.mine();

      // A read is only worth applying while it is still the newest thing said
      // about this account. A write that began after this call left has already
      // answered a fresher account, and a read that overtook it would put the
      // picture or the details the reader just changed back as they were.
      //
      // Nothing is said when it is dropped: what is on the screen is newer than
      // what this read is holding, which is the outcome the reader wanted.
      if (_lock.writes == writesBefore && mark.stillHolds(_session)) {
        _session.accountChanged(read);
      }
    } on ApiException catch (failure) {
      if (!isDisposed) {
        _refreshFailure = failure;
      }
    }

    _isRefreshing = false;
    publish();
  }

  // The camera or the gallery, and then the write. Choosing is outside the lock
  // because a reader lining up a photograph is not a request in flight.
  Future<bool> choosePicture(PictureOrigin origin) async {
    _clearPictureFault();

    final PictureChoice chosen = await _pictures.pick(origin);
    if (isDisposed) {
      return false;
    }

    switch (chosen) {
      case PictureDeclined():
        return false;
      case PictureRefused(:final String message):
        _pictureRefusal = message;
        publish();

        return false;
      case PictureChosen(:final ImageUpload picture):
        // Refused here rather than sent and refused: the bytes are read either
        // way, and this client mirrors the rule the server would answer with.
        if (picture.refusal case final String refusal) {
          _pictureRefusal = refusal;
          publish();

          return false;
        }

        return _writePicture(() => _profile.setPicture(picture));
    }
  }

  Future<bool> removePicture() {
    _clearPictureFault();

    return _writePicture(_profile.clearPicture);
  }

  // What the write answers reaches the session whether or not this screen is
  // still there to draw it: the account belongs to the session, and a write the
  // reader asked for is not one to abandon because they moved on. What it may
  // not reach is a session that has since become somebody else's.
  Future<bool> _writePicture(Future<User> Function() write) =>
      _lock.holding(() async {
        _isSavingPicture = true;
        publish();

        final SessionMark mark = SessionMark.of(_session);

        try {
          final User written = await write();

          if (mark.stillHolds(_session)) {
            _session.accountChanged(written);
          }

          return true;
        } on ApiException catch (failure) {
          if (!isDisposed) {
            _pictureFailure = failure;
          }

          return false;
        } finally {
          _isSavingPicture = false;
          publish();
        }
      });

  void _clearPictureFault() {
    if (_pictureFailure == null && _pictureRefusal == null) {
      return;
    }

    _pictureFailure = null;
    _pictureRefusal = null;
    publish();
  }
}
