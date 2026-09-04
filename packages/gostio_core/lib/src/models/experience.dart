import 'package:json_annotation/json_annotation.dart';

import 'listing_address.dart';

part 'experience.g.dart';

@JsonSerializable(createToJson: false)
class Experience {
  const Experience({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.description,
    required this.experienceCategoryId,
    required this.experienceCategoryName,
    required this.cityId,
    required this.cityName,
    required this.countryName,
    required this.meetingPoint,
    required this.latitude,
    required this.longitude,
    required this.durationMinutes,
    required this.pricePerPerson,
    required this.isActive,
    required this.reviewCount,
    required this.createdAt,
    this.coverPhotoId,
    this.averageRating,
  });

  factory Experience.fromJson(Map<String, dynamic> json) =>
      _$ExperienceFromJson(json);

  final int id;
  final int hostId;
  final String hostName;
  final String title;
  final String description;
  final int experienceCategoryId;
  final String experienceCategoryName;
  final int cityId;
  final String cityName;
  final String countryName;
  final String meetingPoint;
  final double latitude;
  final double longitude;
  final int durationMinutes;
  final double pricePerPerson;
  final bool isActive;
  final int? coverPhotoId;
  final double? averageRating;
  final int reviewCount;
  final DateTime createdAt;

  // No list carries bytes, so a row names the picture and the widget fetches it.
  String? get coverPath => coverPhotoId == null
      ? null
      : ListingAddress(ListingKind.experience, id).photoContent(coverPhotoId!);
}
