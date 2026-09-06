import 'package:json_annotation/json_annotation.dart';

import 'recommendation_reason_kind.dart';

part 'recommendation_reason.g.dart';

@JsonSerializable(createToJson: false)
class RecommendationReason {
  const RecommendationReason({required this.kind, this.detail});

  factory RecommendationReason.fromJson(Map<String, dynamic> json) =>
      _$RecommendationReasonFromJson(json);

  @JsonKey(unknownEnumValue: RecommendationReasonKind.unknown)
  final RecommendationReasonKind kind;

  // The value the reason names — a city, a category, an amenity, a word that
  // was searched for, a rating, a count. A kind that names none leaves this
  // empty: a price near the one being looked at is the reason itself.
  final String? detail;
}
