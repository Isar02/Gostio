import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/host_application_repository.dart';

// Where this account stands on hosting, and the one write that changes it.
//
// The standing is read rather than assumed: an administrator answers an
// application somewhere else entirely, and this client learns about it by
// asking. Applying is the screen's one request and comes through the notifier
// every other single-request screen uses.
class HostApplicationNotifier extends ScreenNotifier {
  HostApplicationNotifier(this._applications);

  final HostApplicationRepository _applications;

  HostApplication? _application;
  bool _hasRead = false;
  int _readers = 0;
  ApiException? _readFailure;

  // How many applications this screen has actually made. A read that began
  // before one of them answers the account as it stood before it, so the read
  // compares this figure against the one it started with rather than putting
  // an empty standing back over an application the reader has just sent.
  int _applicationAttempts = 0;

  // The newest application on this account, or none. It is only worth reading
  // once `hasRead` says the server has answered: until then, none means
  // nothing has been asked rather than that nothing was found.
  HostApplication? get application => _application;

  bool get hasRead => _hasRead;

  bool get isReading => _readers > 0;

  String? get readFailureMessage => _readFailure?.message;

  String? get readFailureTraceId => _readFailure?.traceId;

  // What the server said about an application it would not take. It has no
  // field of its own — this client sends no fields — so it is one sentence
  // beside the button rather than under a control.
  String? get refusal => failure?.message;

  Future<void> read() => _read();

  Future<void> _read({bool alongsideOlderRead = false}) async {
    // An application already on its way answers a newer standing than any read
    // begun beside it could, so there is nothing useful for a second question
    // to do while one is out.
    if ((!alongsideOlderRead && isReading) || isBusy) {
      return;
    }

    _readers++;
    _readFailure = null;
    publish();

    final int attemptsBefore = _applicationAttempts;

    HostApplication? read;
    ApiException? refused;

    try {
      read = await _applications.mine();
    } on ApiException catch (thrown) {
      refused = thrown;
    }

    _readers--;

    if (isDisposed) {
      return;
    }

    // A read is only worth applying while it is still the newest thing said
    // about this account. An application that began after this call left has
    // already answered a fresher standing, so both what this read holds and
    // what refused it belong to a question that has since been answered
    // better.
    if (_applicationAttempts == attemptsBefore) {
      // A refused read leaves the standing as it was rather than claiming this
      // account has never applied. The two are not the same answer, and only
      // one of them offers a button.
      if (refused == null) {
        _application = read;
        _hasRead = true;
      }

      _readFailure = refused;
    }

    publish();
  }

  Future<bool> apply() async {
    if (isBusy) {
      return false;
    }

    // Beginning an application makes every older read stale, whether the
    // server accepts the write or tells us that another device got there
    // first. In the latter case the refusal is reconciled by a fresh read
    // below while the overtaken one is allowed to finish harmlessly.
    _applicationAttempts++;

    final bool sent = await performRequest(() async {
      _application = await _applications.apply();
      _hasRead = true;
    });

    // A refusal is the server saying this account is not where the screen
    // thinks it is — already hosting, or already waiting on an answer — so
    // what is drawn under the sentence is read again rather than left standing
    // as the picture that was just contradicted.
    if (!sent && !isDisposed) {
      await _read(alongsideOlderRead: true);
    }

    return sent;
  }
}
