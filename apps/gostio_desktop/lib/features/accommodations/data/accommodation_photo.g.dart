// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accommodation_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccommodationPhoto _$AccommodationPhotoFromJson(Map<String, dynamic> json) =>
    AccommodationPhoto(
      id: (json['id'] as num).toInt(),
      listingId: (json['listingId'] as num).toInt(),
      contentType: json['contentType'] as String,
      isCover: json['isCover'] as bool,
      displayOrder: (json['displayOrder'] as num).toInt(),
      sizeInBytes: (json['sizeInBytes'] as num).toInt(),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
