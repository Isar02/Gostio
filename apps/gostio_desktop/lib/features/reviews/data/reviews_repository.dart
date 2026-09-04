import 'package:gostio_core/gostio_core.dart';

import 'review_query.dart';

class ReviewsRepository {
  const ReviewsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Review>> search({
    required ReviewQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/reviews',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<Review>.fromJson(
      body,
      (Object? item) => Review.fromJson(item! as JsonMap),
    );
  }

  // A review is the guest's to leave; the booking is the only address it has.
  Future<void> takeDown(int reservationId) =>
      _client.delete('/reservations/$reservationId/review');
}
