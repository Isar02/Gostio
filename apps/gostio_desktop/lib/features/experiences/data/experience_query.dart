import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class ExperienceQuery {
  const ExperienceQuery({
    this.title,
    this.cityId,
    this.experienceCategoryId,
    this.minPrice,
    this.maxPrice,
    this.maxDurationMinutes,
    this.isActive,
  });

  final String? title;
  final int? cityId;
  final int? experienceCategoryId;
  final double? minPrice;
  final double? maxPrice;
  final int? maxDurationMinutes;
  final bool? isActive;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'title': ?_written(title),
    'cityId': ?cityId,
    'experienceCategoryId': ?experienceCategoryId,
    'minPrice': ?minPrice,
    'maxPrice': ?maxPrice,
    'maxDurationMinutes': ?maxDurationMinutes,
    'isActive': ?isActive,
  };

  @override
  bool operator ==(Object other) =>
      other is ExperienceQuery &&
      other.title == title &&
      other.cityId == cityId &&
      other.experienceCategoryId == experienceCategoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.maxDurationMinutes == maxDurationMinutes &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    title,
    cityId,
    experienceCategoryId,
    minPrice,
    maxPrice,
    maxDurationMinutes,
    isActive,
  );

  static String? _written(String? value) {
    final String? written = value?.trim();

    return written == null || written.isEmpty ? null : written;
  }
}
