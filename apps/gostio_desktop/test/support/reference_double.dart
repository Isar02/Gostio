import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';

// Nine screens outside the reference feature read one or two of its tables.
// Everything they do not ask for is refused here once rather than restated as
// a stub in every test that composes one of them, so a test that reaches past
// what it set up still fails where it stands.
class ReferenceDouble implements ReferenceRepository {
  const ReferenceDouble();

  @override
  Future<List<LookupItem>> countriesHoldingCities() =>
      throw UnimplementedError();

  @override
  Future<List<LookupItem>> cities() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> accommodationTypes() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> accommodationCategories() =>
      throw UnimplementedError();

  @override
  Future<List<LookupItem>> experienceCategories() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> amenities() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> reservationStatuses() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> roles() => throw UnimplementedError();

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();
}
