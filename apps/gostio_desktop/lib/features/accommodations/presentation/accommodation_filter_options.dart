import 'package:flutter/foundation.dart';

import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';

@immutable
class AccommodationFilterOptions {
  const AccommodationFilterOptions({
    required this.cities,
    required this.types,
    required this.categories,
    required this.amenities,
  });

  static const AccommodationFilterOptions none = AccommodationFilterOptions(
    cities: <LookupItem>[],
    types: <LookupItem>[],
    categories: <LookupItem>[],
    amenities: <LookupItem>[],
  );

  // None of the four depends on the others, so they are asked for together.
  static Future<AccommodationFilterOptions> load(
    ReferenceRepository reference,
  ) async {
    final (
      List<LookupItem> cities,
      List<LookupItem> types,
      List<LookupItem> categories,
      List<LookupItem> amenities,
    ) = await (
      reference.cities(),
      reference.accommodationTypes(),
      reference.accommodationCategories(),
      reference.amenities(),
    ).wait;

    return AccommodationFilterOptions(
      cities: cities,
      types: types,
      categories: categories,
      amenities: amenities,
    );
  }

  final List<LookupItem> cities;
  final List<LookupItem> types;
  final List<LookupItem> categories;
  final List<LookupItem> amenities;
}
