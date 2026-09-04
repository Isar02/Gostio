import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/reviews/data/review_query.dart';
import 'package:gostio_desktop/features/reviews/data/reviews_repository.dart';

// What the list was asked for and what it was told: reviews are read and
// taken down here, and nothing else is written from this client.
class ReviewsDouble implements ReviewsRepository {
  ReviewsDouble({
    this.rows = const <Review>[],
    int? totalCount,
    this.refusing,
    this.failing = false,
  }) : totalCount = totalCount ?? rows.length;

  final List<Review> rows;
  final int totalCount;

  // What a take-down comes back with, and whether a read comes back at all.
  final ApiException? refusing;
  final bool failing;

  final List<int> pages = <int>[];
  final List<ReviewQuery> queries = <ReviewQuery>[];
  final List<int> takenDown = <int>[];

  @override
  Future<PagedResult<Review>> search({
    required ReviewQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pages.add(page);
    queries.add(query);

    if (failing) {
      throw const ApiException(
        message: 'The reviews could not be read.',
        traceId: '4b91ec',
      );
    }

    return PagedResult<Review>(
      items: rows,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<void> takeDown(int reservationId) async {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    takenDown.add(reservationId);
  }
}
