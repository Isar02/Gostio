import '../../../core/state/screen_notifier.dart';
import '../data/auth_repository.dart';

class ResetPasswordNotifier extends ScreenNotifier {
  ResetPasswordNotifier(this._repository);

  final AuthRepository _repository;

  // The reset issues no token: the account signs in with the new password,
  // which is also what proves it arrived.
  Future<bool> reset({
    required String code,
    required String newPassword,
    required String confirmNewPassword,
  }) => performRequest(
    () => _repository.resetPassword(
      code: code,
      newPassword: newPassword,
      confirmNewPassword: confirmNewPassword,
    ),
  );
}
