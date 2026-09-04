import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/auth_repository.dart';

class SignInNotifier extends ScreenNotifier {
  SignInNotifier(this._repository, this._session);

  final AuthRepository _repository;
  final Session _session;

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    AuthResult? result;
    return performRequest(
      () async {
        result = await _repository.signIn(
          username: username,
          password: password,
        );
      },
      onSuccess: () {
        final AuthResult answer = result!;
        _session.begin(account: answer.user, token: answer.token);
      },
    );
  }
}
