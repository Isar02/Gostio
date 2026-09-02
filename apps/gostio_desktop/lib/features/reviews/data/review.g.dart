// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  id: (json['id'] as num).toInt(),
  reservationId: (json['reservationId'] as num).toInt(),
  guestId: (json['guestId'] as num).toInt(),
  guestName: json['guestName'] as String,
  listingTitle: json['listingTitle'] as String,
  rating: (json['rating'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  accommodationId: (json['accommodationId'] as num?)?.toInt(),
  experienceId: (json['experienceId'] as num?)?.toInt(),
  comment: json['comment'] as String?,
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);
