import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

Map<String, dynamic> suggestion({
  String target = 'Accommodations',
  int? coverPhotoId,
  List<Map<String, dynamic>> reasons = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'listingId': 42,
  'target': target,
  'title': 'Old town loft with a Baščaršija view',
  'cityName': 'Sarajevo',
  'countryName': 'Bosnia and Herzegovina',
  'categoryName': 'City break',
  'price': 95.0,
  'coverPhotoId': coverPhotoId,
  'averageRating': 4.6,
  'reviewCount': 12,
  'score': 0.8123,
  'reasons': reasons,
};

void main() {
  test('the catalogue a suggestion was ranked in addresses its listing', () {
    expect(
      Recommendation.fromJson(suggestion()).listing,
      const ListingAddress(ListingKind.accommodation, 42),
    );
    expect(
      Recommendation.fromJson(suggestion(target: 'Experiences')).listing,
      const ListingAddress(ListingKind.experience, 42),
    );
  });

  test('the cover is named against the listing that holds it', () {
    expect(
      Recommendation.fromJson(suggestion(coverPhotoId: 118)).coverPath,
      '/accommodations/42/photos/118/content',
    );
    expect(Recommendation.fromJson(suggestion()).coverPath, isNull);
  });

  test('a reason carries its kind and the value it names', () {
    final Recommendation picked = Recommendation.fromJson(
      suggestion(
        reasons: <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'City', 'detail': 'Sarajevo'},
          <String, dynamic>{'kind': 'Price', 'detail': null},
        ],
      ),
    );

    expect(picked.reasons.first.kind, RecommendationReasonKind.city);
    expect(picked.reasons.first.detail, 'Sarajevo');
    expect(picked.reasons.last.kind, RecommendationReasonKind.price);
    expect(picked.reasons.last.detail, isNull);
  });

  // A kind added to the server after this build shipped is still a reason it
  // gave, and it must not take the whole page down with it.
  test('a kind this build does not know is read rather than refused', () {
    final Recommendation picked = Recommendation.fromJson(
      suggestion(
        reasons: <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'Weather', 'detail': 'Sunny'},
        ],
      ),
    );

    expect(picked.reasons.single.kind, RecommendationReasonKind.unknown);
  });
}
