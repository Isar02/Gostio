import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class AccommodationQuery {
  const AccommodationQuery({
    this.title,
    this.cityId,
    this.accommodationTypeId,
    this.accommodationCategoryId,
    this.minPrice,
    this.maxPrice,
    this.minGuests,
    this.amenityIds = const <int>[],
    this.isActive,
  });

  final String? title;
  final int? cityId;
  final int? accommodationTypeId;
  final int? accommodationCategoryId;
  final double? minPrice;
  final double? maxPrice;
  final int? minGuests;
  final List<int> amenityIds;
  final bool? isActive;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'title': ?_written(title),
    'cityId': ?cityId,
    'accommodationTypeId': ?accommodationTypeId,
    'accommodationCategoryId': ?accommodationCategoryId,
    'minPrice': ?minPrice,
    'maxPrice': ?maxPrice,
    'minGuests': ?minGuests,
    'isActive': ?isActive,
    if (amenityIds.isNotEmpty) 'amenityIds': amenityIds,
  };

  @override
  bool operator ==(Object other) =>
      other is AccommodationQuery &&
      other.title == title &&
      other.cityId == cityId &&
      other.accommodationTypeId == accommodationTypeId &&
      other.accommodationCategoryId == accommodationCategoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.minGuests == minGuests &&
      other.isActive == isActive &&
      listEquals(other.amenityIds, amenityIds);

  @override
  int get hashCode => Object.hash(
    title,
    cityId,
    accommodationTypeId,
    accommodationCategoryId,
    minPrice,
    maxPrice,
    minGuests,
    isActive,
    Object.hashAll(amenityIds),
  );

  static String? _written(String? value) {
    final String? written = value?.trim();

    return written == null || written.isEmpty ? null : written;
  }
}
