import 'package:json_annotation/json_annotation.dart';

import 'listing_address.dart';
import 'recommendation_reason.dart';

part 'recommendation.g.dart';

// One listing the server suggests, and why. The route answers a whole
// catalogue ranked best first, so the order a page arrives in is the order it
// is read in; the score behind that order is not carried here, because two
// requests are ranked separately and a figure that cannot be compared is a
// figure nothing may draw.
@JsonSerializable(createToJson: false)
class Recommendation {
  const Recommendation({
    required this.listingId,
    required this.target,
    required this.title,
    required this.cityName,
    required this.countryName,
    required this.categoryName,
    required this.price,
    required this.reviewCount,
    required this.reasons,
    this.coverPhotoId,
    this.averageRating,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);

  final int listingId;

  // Which catalogue this was ranked inside, named rather than numbered.
  final ListingKind target;

  final String title;
  final String cityName;
  final String countryName;
  final String categoryName;

  // Per night for a stay and per person for a term, which is whichever
  // catalogue the target names.
  final double price;

  final int? coverPhotoId;
  final double? averageRating;
  final int reviewCount;

  // What the server read off the score. Never empty: a listing nothing spoke
  // for carries the one reason that says so.
  final List<RecommendationReason> reasons;

  ListingAddress get listing => ListingAddress(target, listingId);

  // No list carries bytes, so a row names the picture and the widget fetches it.
  String? get coverPath => switch (coverPhotoId) {
    final int photoId => listing.photoContent(photoId),
    null => null,
  };
}
