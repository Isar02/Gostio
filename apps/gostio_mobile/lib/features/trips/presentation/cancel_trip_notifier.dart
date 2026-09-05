import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/trips_repository.dart';

// Calling one booking off: what it would send back, and the write itself.
//
// The quote is read as this is made rather than carried down from the list,
// because it moves with the clock right up to the cancellation. A quote that
// could not be read leaves the cancellation on offer: this is what calling the
// booking off costs rather than what calling it off does, and the server works
// the amount out either way.
class CancelTripNotifier extends ScreenNotifier {
  CancelTripNotifier(this._trips, this._bookingId, this._onCancelled);

  final TripsRepository _trips;
  final int _bookingId;
  final ValueChanged<Reservation> _onCancelled;

  RefundQuote? _quote;
  bool _isReadingQuote = false;
  int _quoteRequest = 0;

  RefundQuote? get quote => _quote;

  bool get isReadingQuote => _isReadingQuote;

  // A refusal that named the field is drawn under that field. Only one about
  // the booking as a whole is said over the button.
  String? get refusal {
    final ApiException? refused = failure;

    return refused == null || refused.faultsAField ? null : refused.message;
  }

  // The quote belongs to the decision in the sheet and is read afresh whenever
  // that decision opens. An older read cannot land on a later opening.
  void prepare() {
    final int request = ++_quoteRequest;
    _quote = null;
    _isReadingQuote = true;
    clearFailure();
    publish();
    unawaited(_readQuote(request));
  }

  // The returned row goes straight to the owner that outlives the sheet. The
  // sheet gets only whether its request succeeded, which is all it needs to
  // decide whether it should close or show a refusal.
  Future<bool> cancel(String reason) async {
    if (isBusy) {
      return false;
    }

    return performRequest(() async {
      final Reservation cancelled = await _trips.cancel(
        _bookingId,
        reason: reason,
      );
      _onCancelled(cancelled);
    });
  }

  Future<void> _readQuote(int request) async {
    RefundQuote? read;

    try {
      read = await _trips.refundQuote(_bookingId);
    } on ApiException {
      read = null;
    }

    if (isDisposed || request != _quoteRequest) {
      return;
    }

    _quote = read;
    _isReadingQuote = false;
    publish();
  }
}
