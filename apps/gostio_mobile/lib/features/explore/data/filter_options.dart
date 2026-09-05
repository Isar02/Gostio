import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// The choices the two filter sheets offer. They are reference rows rather than
// results, so they are read once for the client and held: a sheet that fetched
// its own choices would ask again every time a thumb opened it.
@immutable
class FilterOptions {
  const FilterOptions({
    this.cities = const <LookupItem>[],
    this.stayTypes = const <LookupItem>[],
    this.stayCategories = const <LookupItem>[],
    this.experienceCategories = const <LookupItem>[],
    this.amenities = const <LookupItem>[],
  });

  static const FilterOptions none = FilterOptions();

  final List<LookupItem> cities;
  final List<LookupItem> stayTypes;
  final List<LookupItem> stayCategories;
  final List<LookupItem> experienceCategories;
  final List<LookupItem> amenities;

  bool get isEmpty =>
      cities.isEmpty &&
      stayTypes.isEmpty &&
      stayCategories.isEmpty &&
      experienceCategories.isEmpty &&
      amenities.isEmpty;
}
