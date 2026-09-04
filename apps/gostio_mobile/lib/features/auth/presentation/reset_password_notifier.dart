import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/auth_repository.dart';

class ResetPasswordNotifier extends ScreenNotifier {
  ResetPasswordNotifier(this._repository);

  final AuthRepository _repository;

  bool _isBusy = false;
  bool _wasReset = false;
  ApiException? _failure;

  bool get isBusy => _isBusy;

  bool get wasReset => _wasReset;

  ApiException? get failure => _failure;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  // The reset issues no token: the account signs in with the new password,
  // which is also what proves it arrived.
  Future<void> reset({
    required String code,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    _isBusy = true;
    _failure = null;
    publish();

    try {
      await _repository.resetPassword(
        code: code,
        newPassword: newPassword,
        confirmNewPassword: confirmNewPassword,
      );
      _wasReset = true;
    } on ApiException catch (failure) {
      _failure = failure;
    } finally {
      _isBusy = false;
      publish();
    }
  }
}
