import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/recommendations_repository.dart';

// What is suggested from one catalogue. The catalogue is the whole query, so
// moving between the two is `apply` rather than a second list kept alive: the
// server reranks the whole catalogue on every request anyway, and a page held
// from the last time this one was in front would be a ranking that has since
// been recomputed.
class RecommendationsNotifier
    extends PagedNotifier<Recommendation, ListingKind> {
  RecommendationsNotifier(this._recommendations)
    : super(ListingKind.accommodation) {
    unawaited(reload());
  }

  final RecommendationsRepository _recommendations;

  @override
  @protected
  Future<PagedResult<Recommendation>> fetch({
    required int page,
    required ListingKind query,
  }) =>
      _recommendations.picks(catalogue: query, page: page, pageSize: pageSize);
}
