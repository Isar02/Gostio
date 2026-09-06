import 'package:gostio_core/gostio_core.dart';

// A suggestion the way the recommendations route answers one. A test names
// only what it is about; the rest is a plausible row from the seed.
Recommendation pick({
  int listingId = 42,
  ListingKind target = ListingKind.accommodation,
  String title = 'Old town loft with a Baščaršija view',
  String cityName = 'Sarajevo',
  String categoryName = 'City break',
  double price = 160,
  double? averageRating = 4.6,
  int reviewCount = 12,
  List<RecommendationReason> reasons = const <RecommendationReason>[],
}) => Recommendation(
  listingId: listingId,
  target: target,
  title: title,
  cityName: cityName,
  countryName: 'Bosnia and Herzegovina',
  categoryName: categoryName,
  price: price,
  averageRating: averageRating,
  reviewCount: reviewCount,
  reasons: reasons,
);

RecommendationReason because(RecommendationReasonKind kind, [String? detail]) =>
    RecommendationReason(kind: kind, detail: detail);

List<Recommendation> picks(
  int count, {
  required ListingKind target,
}) => <Recommendation>[
  for (int index = 1; index <= count; index++)
    pick(
      listingId: index,
      target: target,
      title:
          '${target == ListingKind.accommodation ? 'Stay' : 'Term'} '
          '$index',
      price: 100 + index.toDouble(),
      reasons: <RecommendationReason>[because(RecommendationReasonKind.price)],
    ),
];
