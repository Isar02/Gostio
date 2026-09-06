// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Favorite _$FavoriteFromJson(Map<String, dynamic> json) => Favorite(
  id: (json['id'] as num).toInt(),
  listingTitle: json['listingTitle'] as String,
  cityName: json['cityName'] as String,
  countryName: json['countryName'] as String,
  price: (json['price'] as num).toDouble(),
  isListingActive: json['isListingActive'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  accommodationId: (json['accommodationId'] as num?)?.toInt(),
  experienceId: (json['experienceId'] as num?)?.toInt(),
  coverPhotoId: (json['coverPhotoId'] as num?)?.toInt(),
);
