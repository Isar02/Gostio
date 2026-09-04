import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/paging/writing_notifier.dart';
import '../data/review_query.dart';
import '../data/reviews_repository.dart';

class ReviewsNotifier extends PagedNotifier<Review, ReviewQuery>
    with WritingNotifier<Review, ReviewQuery> {
  ReviewsNotifier(this._reviews) : super(const ReviewQuery());

  final ReviewsRepository _reviews;

  @override
  Future<PagedResult<Review>> fetch({
    required int page,
    required ReviewQuery query,
  }) => _reviews.search(query: query, page: page, pageSize: pageSize);

  // Nothing is added here, so the page the row stood on is read again.
  Future<WriteOutcome> takeDown(int reservationId) =>
      write(() => _reviews.takeDown(reservationId));
}
