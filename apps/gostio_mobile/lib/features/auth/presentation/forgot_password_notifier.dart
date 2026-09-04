import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/auth_repository.dart';

class ForgotPasswordNotifier extends ScreenNotifier {
  ForgotPasswordNotifier(this._repository);

  final AuthRepository _repository;

  bool _isBusy = false;
  bool _wasAsked = false;
  ApiException? _failure;

  bool get isBusy => _isBusy;

  // The API accepts the request whether or not the address is on an account,
  // so this says a code was asked for rather than that one was sent.
  bool get wasAsked => _wasAsked;

  ApiException? get failure => _failure;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  Future<void> ask(String email) async {
    _isBusy = true;
    _failure = null;
    publish();

    try {
      await _repository.forgotPassword(email);
      _wasAsked = true;
    } on ApiException catch (failure) {
      _failure = failure;
    } finally {
      _isBusy = false;
      publish();
    }
  }
}
