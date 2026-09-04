import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/account_registration.dart';
import '../data/auth_repository.dart';

class RegisterNotifier extends ScreenNotifier {
  RegisterNotifier(this._repository, this._session);

  final AuthRepository _repository;
  final Session _session;

  bool _isBusy = false;
  ApiException? _failure;

  bool get isBusy => _isBusy;

  ApiException? get failure => _failure;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  // An account opens signed in: the API answers a registration with the same
  // token a sign in would have been given.
  Future<void> register(AccountRegistration registration) async {
    _isBusy = true;
    _failure = null;
    publish();

    try {
      final AuthResult result = await _repository.register(registration);

      _isBusy = false;
      _session.begin(account: result.user, token: result.token);
    } on ApiException catch (failure) {
      _isBusy = false;
      _failure = failure;
      publish();
    } on Object {
      _isBusy = false;
      publish();
      rethrow;
    }
  }
}
