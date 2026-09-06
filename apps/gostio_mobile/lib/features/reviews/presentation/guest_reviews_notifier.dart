import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/reviews_repository.dart';

// What this account has written, newest first as the server orders it. The
// account is the whole query, so the paging carries nothing of its own.
class GuestReviewsNotifier extends PagedNotifier<Review, void> {
  GuestReviewsNotifier(this._reviews, this._guestId) : super(null) {
    unawaited(reload());
  }

  final ReviewsRepository _reviews;
  final int _guestId;

  // What the screen this list opened left of one review: the row as the
  // server now holds it, or nothing where the reader took it back. The pages
  // already read stay where they are, because reading the list again would
  // take one several pages deep back to its first page over a single row.
  void changedFor(int reservationId, Review? review) {
    bool isTheOne(Review held) => held.reservationId == reservationId;

    if (review == null) {
      removeWhere(isTheOne);
    } else {
      replaceWhere(isTheOne, review);
    }
  }

  @override
  @protected
  Future<PagedResult<Review>> fetch({required int page, required void query}) =>
      _reviews.byGuest(guestId: _guestId, page: page, pageSize: pageSize);
}
