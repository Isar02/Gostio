import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../data/auth_repository.dart';

class SignInNotifier extends ChangeNotifier {
  SignInNotifier(this._repository, this._session);

  final AuthRepository _repository;
  final Session _session;

  bool _isBusy = false;
  ApiException? _failure;

  bool get isBusy => _isBusy;

  String? get failureMessage => _failure?.message;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    _isBusy = true;
    _failure = null;
    notifyListeners();

    try {
      final AuthResult result = await _repository.signIn(
        username: username,
        password: password,
      );

      // Beginning the session replaces this screen, so nothing is notified
      // after it: the notifier is disposed by the time the call returns.
      _isBusy = false;
      _session.begin(account: result.user, token: result.token);
    } on ApiException catch (failure) {
      _isBusy = false;
      _failure = failure;
      notifyListeners();
    } on Object {
      _isBusy = false;
      notifyListeners();
      rethrow;
    }
  }
}
