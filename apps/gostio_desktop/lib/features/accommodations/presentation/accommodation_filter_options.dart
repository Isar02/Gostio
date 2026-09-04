import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

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
  // Future.wait rather than a record's, which reports the failures wrapped in
  // one of its own and would hide the sentence the API wrote.
  static Future<AccommodationFilterOptions> load(
    ReferenceRepository reference,
  ) async {
    final List<List<LookupItem>> tables = await Future.wait(
      <Future<List<LookupItem>>>[
        reference.cities(),
        reference.accommodationTypes(),
        reference.accommodationCategories(),
        reference.amenities(),
      ],
    );

    return AccommodationFilterOptions(
      cities: tables[0],
      types: tables[1],
      categories: tables[2],
      amenities: tables[3],
    );
  }

  final List<LookupItem> cities;
  final List<LookupItem> types;
  final List<LookupItem> categories;
  final List<LookupItem> amenities;
}
