import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/reviews_repository.dart';

// The one review a booking may carry: whether it has one, and the three
// writes that can change that. A booking is reviewed once, so leaving a
// review and changing it are the same decision made twice and are sent
// through one method here.
//
// It belongs to the route that draws the booking rather than to the sheet the
// words are typed in. A write outlives that sheet, so what it answers is
// given to something that also outlives it, and what the list behind is told
// is the row the server handed back.
class BookingReviewNotifier extends ScreenNotifier {
  BookingReviewNotifier(
    this._reviews,
    this._reservationId, {
    Review? review,
    this.onChanged,
  }) : _review = review,
       _hasRead = review != null;

  final ReviewsRepository _reviews;
  final int _reservationId;

  // The review as the server now holds it, for whatever opened this: a list
  // showing the row, a screen drawing it, or both.
  final ValueChanged<Review?>? onChanged;

  Review? _review;
  bool _hasRead;
  bool _isReading = false;
  ApiException? _readFailure;

  Review? get review => _review;

  bool get isReading => _isReading;

  // Whether the booking has been asked about at all. Until it has, nothing is
  // offered: a booking whose review could not be read is not one to invite a
  // second review of.
  bool get hasRead => _hasRead;

  String? get readFailure => _readFailure?.message;

  // A refusal that named the field is drawn under that field. Only one about
  // the review as a whole is said over the button.
  String? get refusal {
    final ApiException? refused = failure;

    return refused == null || refused.faultsAField ? null : refused.message;
  }

  // Read when the section is first drawn and not again. A booking nobody may
  // review yet never draws it, so nothing asks the server about one.
  Future<void> readOnce() async {
    if (_hasRead || _isReading) {
      return;
    }

    _isReading = true;
    _readFailure = null;
    publish();

    Review? read;
    ApiException? refused;

    try {
      read = await _reviews.forBooking(_reservationId);
    } on ApiException catch (thrown) {
      refused = thrown;
    }

    if (isDisposed) {
      return;
    }

    // A read that was refused leaves the section saying so rather than
    // claiming the booking has no review: the two are not the same answer.
    if (refused == null) {
      _review = read;
      _hasRead = true;
    }

    _readFailure = refused;
    _isReading = false;
    publish();
  }

  Future<bool> save({required int rating, String? comment}) async {
    if (isBusy) {
      return false;
    }

    final bool exists = _review != null;

    return performRequest(() async {
      final Review written = exists
          ? await _reviews.rewrite(
              _reservationId,
              rating: rating,
              comment: comment,
            )
          : await _reviews.write(
              _reservationId,
              rating: rating,
              comment: comment,
            );

      _accept(written);
    });
  }

  Future<bool> takeDown() async {
    if (isBusy) {
      return false;
    }

    return performRequest(() async {
      await _reviews.takeDown(_reservationId);
      _accept(null);
    });
  }

  void _accept(Review? review) {
    _review = review;
    _hasRead = true;
    onChanged?.call(review);
  }
}
