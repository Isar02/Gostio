import 'package:json_annotation/json_annotation.dart';

import 'listing_address.dart';

part 'review.g.dart';

// Written on the mobile side and only ever read here.
@JsonSerializable(createToJson: false)
class Review {
  const Review({
    required this.id,
    required this.reservationId,
    required this.guestId,
    required this.guestName,
    required this.listingTitle,
    required this.rating,
    required this.createdAt,
    this.accommodationId,
    this.experienceId,
    this.comment,
    this.modifiedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);

  final int id;

  // The review's only address: it is taken down through its booking.
  final int reservationId;

  final int guestId;
  final String guestName;
  final int? accommodationId;
  final int? experienceId;
  final String listingTitle;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  ListingKind? get listingKind => switch ((accommodationId, experienceId)) {
    (final int _, _) => ListingKind.accommodation,
    (_, final int _) => ListingKind.experience,
    _ => null,
  };

  bool get wasEdited => modifiedAt != null;
}
