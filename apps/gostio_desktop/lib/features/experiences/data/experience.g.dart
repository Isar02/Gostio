// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experience.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Experience _$ExperienceFromJson(Map<String, dynamic> json) => Experience(
  id: (json['id'] as num).toInt(),
  hostId: (json['hostId'] as num).toInt(),
  hostName: json['hostName'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  experienceCategoryId: (json['experienceCategoryId'] as num).toInt(),
  experienceCategoryName: json['experienceCategoryName'] as String,
  cityId: (json['cityId'] as num).toInt(),
  cityName: json['cityName'] as String,
  countryName: json['countryName'] as String,
  meetingPoint: json['meetingPoint'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  durationMinutes: (json['durationMinutes'] as num).toInt(),
  pricePerPerson: (json['pricePerPerson'] as num).toDouble(),
  isActive: json['isActive'] as bool,
  reviewCount: (json['reviewCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  coverPhotoId: (json['coverPhotoId'] as num?)?.toInt(),
  averageRating: (json['averageRating'] as num?)?.toDouble(),
);
