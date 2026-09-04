// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListingPhoto _$ListingPhotoFromJson(Map<String, dynamic> json) => ListingPhoto(
  id: (json['id'] as num).toInt(),
  listingId: (json['listingId'] as num).toInt(),
  contentType: json['contentType'] as String,
  isCover: json['isCover'] as bool,
  displayOrder: (json['displayOrder'] as num).toInt(),
  sizeInBytes: (json['sizeInBytes'] as num).toInt(),
  uploadedAt: DateTime.parse(json['uploadedAt'] as String),
);
