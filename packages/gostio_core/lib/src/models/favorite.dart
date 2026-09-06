import 'package:json_annotation/json_annotation.dart';

import 'listing_address.dart';

part 'favorite.g.dart';

// A listing an account has kept, in the shape the favourites route answers.
// One row covers both catalogues: it carries what a card draws rather than the
// listing behind it, so a saved stay and a saved experience arrive in one list
// in the order they were saved.
@JsonSerializable(createToJson: false)
class Favorite {
  const Favorite({
    required this.id,
    required this.listingTitle,
    required this.cityName,
    required this.countryName,
    required this.price,
    required this.isListingActive,
    required this.createdAt,
    this.accommodationId,
    this.experienceId,
    this.coverPhotoId,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);

  final int id;
  final int? accommodationId;
  final int? experienceId;
  final String listingTitle;
  final String cityName;
  final String countryName;

  // Per night for a stay and per person for a term, which is whichever of the
  // two the row names.
  final double price;

  final int? coverPhotoId;

  // A listing its host has withdrawn stays saved. Nobody but that host may
  // read it any more, so what is kept and what can still be opened are two
  // questions and the row answers both.
  final bool isListingActive;

  final DateTime createdAt;

  // Which listing this is. A row names one of the two ids and never both, and
  // one naming neither is not a listing this client can address.
  ListingAddress? get listing => switch ((accommodationId, experienceId)) {
    (final int id, _) => ListingAddress(ListingKind.accommodation, id),
    (_, final int id) => ListingAddress(ListingKind.experience, id),
    _ => null,
  };

  // No list carries bytes, so a row names the picture and the widget fetches it.
  String? get coverPath => switch ((listing, coverPhotoId)) {
    (final ListingAddress address, final int photoId) => address.photoContent(
      photoId,
    ),
    _ => null,
  };
}
