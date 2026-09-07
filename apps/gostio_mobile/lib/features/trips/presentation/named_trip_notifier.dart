import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/trips_repository.dart';

// One booking read by its id, for the screens that are handed a number rather
// than a row: a notice in the bell's list, and the tap on a delivered one.
//
// A booking outside this account answers 404 like a missing one, which is the
// server's rule and not a case this screen tells apart. It says the read was
// refused, in the server's words, and offers another go.
class NamedTripNotifier extends LiveNotifier {
  NamedTripNotifier(this._repository, this.reservationId) {
    unawaited(load());
  }

  final TripsRepository _repository;
  final int reservationId;

  Reservation? _booking;
  bool _isLoading = false;
  ApiException? _failure;

  Reservation? get booking => _booking;

  bool get isLoading => _isLoading;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _failure = null;
    publish();

    Reservation? read;
    ApiException? refused;

    try {
      read = await _repository.trip(reservationId);
    } on ApiException catch (thrown) {
      refused = thrown;
    }

    if (isDisposed) {
      return;
    }

    if (read != null) {
      _booking = read;
    }

    _failure = refused;
    _isLoading = false;
    publish();
  }

  // What the trip screen answers with after paying it or calling it off. The
  // row it hands back is the booking as the server now holds it.
  void accept(Reservation booking) {
    if (isDisposed) {
      return;
    }

    _booking = booking;
    publish();
  }
}
