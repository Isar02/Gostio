// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accommodation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Accommodation _$AccommodationFromJson(Map<String, dynamic> json) =>
    Accommodation(
      id: (json['id'] as num).toInt(),
      hostId: (json['hostId'] as num).toInt(),
      hostName: json['hostName'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      accommodationTypeId: (json['accommodationTypeId'] as num).toInt(),
      accommodationTypeName: json['accommodationTypeName'] as String,
      accommodationCategoryId: (json['accommodationCategoryId'] as num).toInt(),
      accommodationCategoryName: json['accommodationCategoryName'] as String,
      cityId: (json['cityId'] as num).toInt(),
      cityName: json['cityName'] as String,
      countryName: json['countryName'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      maxGuests: (json['maxGuests'] as num).toInt(),
      bedrooms: (json['bedrooms'] as num).toInt(),
      bathrooms: (json['bathrooms'] as num).toInt(),
      pricePerNight: (json['pricePerNight'] as num).toDouble(),
      cleaningFee: (json['cleaningFee'] as num).toDouble(),
      isActive: json['isActive'] as bool,
      reviewCount: (json['reviewCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      coverPhotoId: (json['coverPhotoId'] as num?)?.toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
    );
