// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recommendation _$RecommendationFromJson(Map<String, dynamic> json) =>
    Recommendation(
      listingId: (json['listingId'] as num).toInt(),
      target: $enumDecode(_$ListingKindEnumMap, json['target']),
      title: json['title'] as String,
      cityName: json['cityName'] as String,
      countryName: json['countryName'] as String,
      categoryName: json['categoryName'] as String,
      price: (json['price'] as num).toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      reasons: (json['reasons'] as List<dynamic>)
          .map((e) => RecommendationReason.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverPhotoId: (json['coverPhotoId'] as num?)?.toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
    );

const _$ListingKindEnumMap = {
  ListingKind.accommodation: 'Accommodations',
  ListingKind.experience: 'Experiences',
};
