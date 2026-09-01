import 'package:flutter/foundation.dart';

import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';

@immutable
class ExperienceFilterOptions {
  const ExperienceFilterOptions({
    required this.cities,
    required this.categories,
  });

  static const ExperienceFilterOptions none = ExperienceFilterOptions(
    cities: <LookupItem>[],
    categories: <LookupItem>[],
  );

  // Neither depends on the other, so they are asked for together.
  static Future<ExperienceFilterOptions> load(
    ReferenceRepository reference,
  ) async {
    final List<List<LookupItem>> tables = await Future.wait(
      <Future<List<LookupItem>>>[
        reference.cities(),
        reference.experienceCategories(),
      ],
    );

    return ExperienceFilterOptions(cities: tables[0], categories: tables[1]);
  }

  final List<LookupItem> cities;
  final List<LookupItem> categories;
}
