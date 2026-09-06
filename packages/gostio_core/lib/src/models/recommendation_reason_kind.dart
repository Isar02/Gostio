import 'package:json_annotation/json_annotation.dart';

// Why the server put a listing in front of a reader, as a kind rather than as
// a sentence: what the reason is worded in is the client's to know.
//
// The first seven are the axes a taste is measured along. The last three are
// what a suggestion carries when fewer than three of those spoke for it, and
// `onOffer` is the one that says nothing did.
enum RecommendationReasonKind {
  @JsonValue('City')
  city,
  @JsonValue('Category')
  category,
  @JsonValue('AccommodationType')
  accommodationType,
  @JsonValue('Amenity')
  amenity,
  @JsonValue('Term')
  term,
  @JsonValue('Price')
  price,
  @JsonValue('Capacity')
  capacity,
  @JsonValue('Rating')
  rating,
  @JsonValue('Popularity')
  popularity,
  @JsonValue('OnOffer')
  onOffer,
  // A kind this build has not caught up with. It is still a reason the server
  // gave, and a client that cannot word it says nothing rather than inventing
  // a sentence around a value it does not understand.
  unknown,
}
