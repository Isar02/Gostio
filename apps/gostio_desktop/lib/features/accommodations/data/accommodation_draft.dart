import '../../../core/network/api_client.dart';

// The listing's own fields as the form holds them. Create and edit are one
// form, so one draft answers both endpoints: a host is named only where an
// administrator creates for somebody else, and the published flag only where a
// listing already exists — a new one is published by the API on its own.
class AccommodationDraft {
  const AccommodationDraft({
    required this.title,
    required this.description,
    required this.accommodationTypeId,
    required this.accommodationCategoryId,
    required this.cityId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.maxGuests,
    required this.bedrooms,
    required this.bathrooms,
    required this.pricePerNight,
    required this.cleaningFee,
  });

  final String title;
  final String description;
  final int accommodationTypeId;
  final int accommodationCategoryId;
  final int cityId;
  final String address;
  final double latitude;
  final double longitude;
  final int maxGuests;
  final int bedrooms;
  final int bathrooms;
  final double pricePerNight;
  final double cleaningFee;

  JsonMap toCreate({int? hostId}) => <String, dynamic>{
    ..._fields,
    'hostId': ?hostId,
  };

  JsonMap toUpdate({required bool isActive}) => <String, dynamic>{
    ..._fields,
    'isActive': isActive,
  };

  JsonMap get _fields => <String, dynamic>{
    'title': title,
    'description': description,
    'accommodationTypeId': accommodationTypeId,
    'accommodationCategoryId': accommodationCategoryId,
    'cityId': cityId,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'maxGuests': maxGuests,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'pricePerNight': pricePerNight,
    'cleaningFee': cleaningFee,
  };
}
