// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accommodation_availability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccommodationAvailability _$AccommodationAvailabilityFromJson(
  Map<String, dynamic> json,
) => AccommodationAvailability(
  id: (json['id'] as num).toInt(),
  accommodationId: (json['accommodationId'] as num).toInt(),
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  isAvailable: json['isAvailable'] as bool,
  priceOverride: (json['priceOverride'] as num?)?.toDouble(),
);
