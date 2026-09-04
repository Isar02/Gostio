import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import 'live_notifier.dart';

// One screen's one request: whether it is in flight, and what the server
// faulted if it was refused. A list holding pages keeps different state and
// does not come through here.
abstract class ScreenNotifier extends LiveNotifier {
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
      if (!isDisposed) {
        onSuccess?.call();

        return true;
      }
    } on ApiException catch (failure) {
      if (!isDisposed) {
        _failure = failure;
      }
    } finally {
      if (!isDisposed) {
        _isBusy = false;
        publish();
      }
    }

    return false;
  }

  void clearFailureFor(String field) {
    final ApiException? failure = _failure;
    if (failure == null || isDisposed) {
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
}
