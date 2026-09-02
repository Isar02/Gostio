import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../listings/data/listing_address.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class ReviewQuery {
  const ReviewQuery({this.listing, this.lowestRating, this.highestRating});

  // The API narrows by accommodation and by experience separately.
  final ListingAddress? listing;

  final int? lowestRating;
  final int? highestRating;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'accommodationId': ?_idOf(ListingKind.accommodation),
    'experienceId': ?_idOf(ListingKind.experience),
    'minRating': ?lowestRating,
    'maxRating': ?highestRating,
  };

  @override
  bool operator ==(Object other) =>
      other is ReviewQuery &&
      other.listing == listing &&
      other.lowestRating == lowestRating &&
      other.highestRating == highestRating;

  @override
  int get hashCode => Object.hash(listing, lowestRating, highestRating);

  int? _idOf(ListingKind kind) {
    final ListingAddress? chosen = listing;

    return chosen == null || chosen.kind != kind ? null : chosen.id;
  }
}
