// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_reason.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationReason _$RecommendationReasonFromJson(
  Map<String, dynamic> json,
) => RecommendationReason(
  kind: $enumDecode(
    _$RecommendationReasonKindEnumMap,
    json['kind'],
    unknownValue: RecommendationReasonKind.unknown,
  ),
  detail: json['detail'] as String?,
);

const _$RecommendationReasonKindEnumMap = {
  RecommendationReasonKind.city: 'City',
  RecommendationReasonKind.category: 'Category',
  RecommendationReasonKind.accommodationType: 'AccommodationType',
  RecommendationReasonKind.amenity: 'Amenity',
  RecommendationReasonKind.term: 'Term',
  RecommendationReasonKind.price: 'Price',
  RecommendationReasonKind.capacity: 'Capacity',
  RecommendationReasonKind.rating: 'Rating',
  RecommendationReasonKind.popularity: 'Popularity',
  RecommendationReasonKind.onOffer: 'OnOffer',
  RecommendationReasonKind.unknown: 'unknown',
};
