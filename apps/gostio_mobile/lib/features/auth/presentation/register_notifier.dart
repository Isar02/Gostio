import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/account_registration.dart';
import '../data/auth_repository.dart';

class RegisterNotifier extends ScreenNotifier {
  RegisterNotifier(this._repository, this._session);

  final AuthRepository _repository;
  final Session _session;

  // An account opens signed in: the API answers a registration with the same
  // token a sign in would have been given.
  Future<bool> register(AccountRegistration registration) async {
    AuthResult? result;
    return performRequest(
      () async {
        result = await _repository.register(registration);
      },
      onSuccess: () {
        final AuthResult answer = result!;
        _session.begin(account: answer.user, token: answer.token);
      },
    );
  }
}
