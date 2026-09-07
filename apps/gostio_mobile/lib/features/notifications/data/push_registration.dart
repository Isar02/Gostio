import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/push/push_messaging.dart';
import 'notifications_repository.dart';

// Where this device says it can be reached, for as long as an account is
// signed in on it. It begins with the session and is given up on the way out.
//
// A phone is handed between people. A registration left behind delivers one
// account's bookings to whoever holds the phone next, which is a disclosure
// rather than an annoyance — so the removal is part of signing out rather than
// something the next sign-in is trusted to correct.
class PushRegistration {
  PushRegistration(this._repository, this._messaging);

  final NotificationsRepository _repository;
  final PushMessaging _messaging;

  StreamSubscription<String>? _rotations;
  String? _registered;
  Future<void> _registrationQueue = Future<void>.value();
  int _rotation = 0;
  bool _hasBeenGivenUp = false;
  bool _isClosed = false;

  // What this device is currently registered as, for a reader of the state
  // rather than for anything that writes.
  String? get deviceToken => _registered;

  Future<void> start() async {
    // The service rotates a token on its own schedule, so the client listens
    // before it asks for one: a rotation between the two would otherwise be
    // the last one nobody heard.
    final int beforeTokenRead = _rotation;
    _rotations ??= _messaging.deviceTokenChanges.listen((String token) {
      _rotation++;
      unawaited(_queueRegistration(token));
    });

    final String? token = await _messaging.deviceToken();
    // A rotation heard while getToken was in flight is newer than its answer.
    if (token != null && beforeTokenRead == _rotation) {
      await _queueRegistration(token);
    }
  }

  // Called while the session's token is still good. Signing out removes the
  // row; a session ended by a refusal cannot, and that registration stays
  // until this device signs in again or the service reports it gone.
  Future<void> forget() async {
    _hasBeenGivenUp = true;

    // Registrations are serialized. Waiting for the queue means every call
    // that began under this session either failed or removed itself before the
    // session token is allowed to end.
    await _registrationQueue;

    final String? token = _registered;
    _registered = null;
    if (token != null) {
      await _forget(token);
    }
  }

  Future<void> close() async {
    _isClosed = true;
    await _rotations?.cancel();
    _rotations = null;
  }

  Future<void> _queueRegistration(String token) {
    _registrationQueue = _registrationQueue.then((void _) => _register(token));

    return _registrationQueue;
  }

  // A registration that was refused is a deployment or a network fault rather
  // than something a reader can act on, and nothing on the screen is waiting
  // for its answer.
  Future<void> _register(String token) async {
    if (_hasBeenGivenUp || _isClosed) {
      return;
    }

    try {
      await _repository.registerDevice(token);
    } on ApiException {
      return;
    }

    // The reader signed out while this was in flight, so the device was
    // registered to an account that has since left it. Taking it back out is
    // the whole point of giving it up.
    if (_hasBeenGivenUp) {
      await _forget(token);

      return;
    }

    if (_isClosed) {
      return;
    }

    final String? previous = _registered;
    _registered = token;
    if (previous != null && previous != token) {
      await _forget(previous);
    }
  }

  Future<void> _forget(String token) async {
    try {
      await _repository.forgetDevice(token);
    } on ApiException {
      return;
    }
  }
}
