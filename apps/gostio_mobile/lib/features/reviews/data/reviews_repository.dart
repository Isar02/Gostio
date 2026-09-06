import 'package:gostio_core/gostio_core.dart';

// What a guest does with a review: read the one against a booking, leave it,
// change it, take it back, and read the ones they have written.
//
// A review has no address of its own on this client. It is written, changed
// and taken down through the booking it is about, which is the only booking a
// guest may review and the only one review it may carry.
class ReviewsRepository {
  const ReviewsRepository(this._client);

  final ApiClient _client;

  // What this account has written, newest first as the server orders it. The
  // guest is named rather than left to the server's wider view of what the
  // caller may see: a host reading this has reviews of their listings too, and
  // those are what was said about them rather than what they said.
  Future<PagedResult<Review>> byGuest({
    required int guestId,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/reviews',
      query: <String, dynamic>{
        'guestId': guestId,
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Review>.fromJson(
      body,
      (Object? item) => Review.fromJson(item! as JsonMap),
    );
  }

  // The review against a booking, or none. The API answers 404 for a booking
  // nobody has reviewed, and to a caller holding that booking already that is
  // an answer rather than a fault.
  Future<Review?> forBooking(int reservationId) async {
    try {
      return Review.fromJson(await _client.get(_addressOf(reservationId)));
    } on ApiException catch (refused) {
      if (refused.isMissing) {
        return null;
      }

      rethrow;
    }
  }

  Future<Review> write(
    int reservationId, {
    required int rating,
    String? comment,
  }) async => Review.fromJson(
    await _client.post(
      _addressOf(reservationId),
      body: _body(rating: rating, comment: comment),
    ),
  );

  Future<Review> rewrite(
    int reservationId, {
    required int rating,
    String? comment,
  }) async => Review.fromJson(
    await _client.put(
      _addressOf(reservationId),
      body: _body(rating: rating, comment: comment),
    ),
  );

  Future<void> takeDown(int reservationId) =>
      _client.delete(_addressOf(reservationId));

  static String _addressOf(int reservationId) =>
      '/reservations/$reservationId/review';

  static JsonMap _body({required int rating, String? comment}) =>
      <String, dynamic>{'rating': rating, 'comment': comment};
}
