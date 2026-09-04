import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A call in flight outlives the screen that started it — a form left through
// Back while it is sending. What the answer wanted to announce is dropped
// rather than thrown at a notifier nobody listens to.
abstract class ScreenNotifier extends ChangeNotifier {
  bool _isDisposed = false;
  bool _isBusy = false;
  ApiException? _failure;

  bool get isBusy => _isBusy;

  ApiException? get failure => _failure;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  @protected
  Future<bool> performRequest(
    Future<void> Function() request, {
    VoidCallback? onSuccess,
  }) async {
    _isBusy = true;
    _failure = null;
    publish();

    try {
      await request();
      if (!_isDisposed) {
        onSuccess?.call();

        return true;
      }
    } on ApiException catch (failure) {
      if (!_isDisposed) {
        _failure = failure;
      }
    } finally {
      if (!_isDisposed) {
        _isBusy = false;
        publish();
      }
    }

    return false;
  }

  void clearFailureFor(String field) {
    final ApiException? failure = _failure;
    if (failure == null || _isDisposed) {
      return;
    }

    if (!failure.faultsAField) {
      _failure = null;
      publish();

      return;
    }

    final Map<String, List<String>> errors = Map<String, List<String>>.of(
      failure.errors,
    );
    final int before = errors.length;
    errors.removeWhere(
      (String name, List<String> messages) =>
          name.toLowerCase() == field.toLowerCase(),
    );
    if (errors.length == before) {
      return;
    }

    _failure = errors.isEmpty
        ? null
        : ApiException(
            message: failure.message,
            statusCode: failure.statusCode,
            errors: errors,
            traceId: failure.traceId,
          );
    publish();
  }

  @protected
  void publish() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    super.dispose();
  }
}
