import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/listing_repository.dart';

// One listing's reviews, newest first as the server orders them. The listing
// is the whole query, so the paging carries nothing of its own.
//
// The first page is read with the screen. The detail draws the top of it and
// the screen behind it draws the whole of it, both from this one list, so
// opening that screen asks the server for nothing it has already answered.
class ListingReviewsNotifier extends PagedNotifier<Review, void> {
  ListingReviewsNotifier(this._repository, this._address) : super(null) {
    unawaited(reload());
  }

  final ListingRepository _repository;
  final ListingAddress _address;

  @override
  @protected
  Future<PagedResult<Review>> fetch({required int page, required void query}) =>
      _repository.reviews(_address, page: page, pageSize: pageSize);
}
