import '../../../core/state/screen_notifier.dart';
import '../data/auth_repository.dart';

class ForgotPasswordNotifier extends ScreenNotifier {
  ForgotPasswordNotifier(this._repository);

  final AuthRepository _repository;

  bool _wasAsked = false;

  // The API accepts the request whether or not the address is on an account,
  // so this says a code was asked for rather than that one was sent.
  bool get wasAsked => _wasAsked;

  Future<bool> ask(String email) => performRequest(
    () => _repository.forgotPassword(email),
    onSuccess: () => _wasAsked = true,
  );
}
