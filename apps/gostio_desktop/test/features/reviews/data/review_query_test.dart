import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reviews/data/review_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    expect(const ReviewQuery().toParameters(), isEmpty);
    expect(const ReviewQuery().isEmpty, isTrue);
  });

  // The API narrows by accommodation and by experience separately, so the one
  // listing chosen reaches the parameter its own catalogue answers.
  test('a listing is sent on the side of the catalogue it is in', () {
    expect(
      const ReviewQuery(listing: ListingAddress(ListingKind.accommodation, 4))
          .toParameters(),
      <String, dynamic>{'accommodationId': 4},
    );
    expect(
      const ReviewQuery(listing: ListingAddress(ListingKind.experience, 12))
          .toParameters(),
      <String, dynamic>{'experienceId': 12},
    );
  });

  test('a band of ratings goes as the two edges the API names', () {
    expect(
      const ReviewQuery(lowestRating: 2, highestRating: 4).toParameters(),
      <String, dynamic>{'minRating': 2, 'maxRating': 4},
    );
  });

  test('two queries holding the same filters are the same query', () {
    const ReviewQuery query = ReviewQuery(
      listing: ListingAddress(ListingKind.experience, 12),
      lowestRating: 3,
    );

    expect(
      query,
      const ReviewQuery(
        listing: ListingAddress(ListingKind.experience, 12),
        lowestRating: 3,
      ),
    );
    expect(query, isNot(const ReviewQuery(lowestRating: 3)));
  });
}
