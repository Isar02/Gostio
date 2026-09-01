import 'package:json_annotation/json_annotation.dart';

import '../../listings/data/listing_address.dart';

part 'accommodation.g.dart';

@JsonSerializable(createToJson: false)
class Accommodation {
  const Accommodation({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.description,
    required this.accommodationTypeId,
    required this.accommodationTypeName,
    required this.accommodationCategoryId,
    required this.accommodationCategoryName,
    required this.cityId,
    required this.cityName,
    required this.countryName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.maxGuests,
    required this.bedrooms,
    required this.bathrooms,
    required this.pricePerNight,
    required this.cleaningFee,
    required this.isActive,
    required this.reviewCount,
    required this.createdAt,
    this.coverPhotoId,
    this.averageRating,
  });

  factory Accommodation.fromJson(Map<String, dynamic> json) =>
      _$AccommodationFromJson(json);

  final int id;
  final int hostId;
  final String hostName;
  final String title;
  final String description;
  final int accommodationTypeId;
  final String accommodationTypeName;
  final int accommodationCategoryId;
  final String accommodationCategoryName;
  final int cityId;
  final String cityName;
  final String countryName;
  final String address;
  final double latitude;
  final double longitude;
  final int maxGuests;
  final int bedrooms;
  final int bathrooms;
  final double pricePerNight;
  final double cleaningFee;
  final bool isActive;
  final int? coverPhotoId;
  final double? averageRating;
  final int reviewCount;
  final DateTime createdAt;

  // No list carries bytes, so a row names the picture and the widget fetches it.
  String? get coverPath => coverPhotoId == null
      ? null
      : ListingAddress(
          ListingKind.accommodation,
          id,
        ).photoContent(coverPhotoId!);
}
