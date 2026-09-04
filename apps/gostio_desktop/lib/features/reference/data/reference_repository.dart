import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/page_walk.dart';
import 'home_country.dart';

class ReferenceRepository {
  const ReferenceRepository(this._client);

  final ApiClient _client;

  Future<List<LookupItem>> countriesHoldingCities() => _all(
    '/countries',
    query: <String, dynamic>{'isoCode': HomeCountry.isoCode},
  );

  Future<List<LookupItem>> cities() => _all('/cities');

  Future<List<LookupItem>> accommodationTypes() => _all('/accommodation-types');

  Future<List<LookupItem>> accommodationCategories() =>
      _all('/accommodation-categories');

  Future<List<LookupItem>> experienceCategories() =>
      _all('/experience-categories');

  Future<List<LookupItem>> amenities() => _all('/amenities');

  Future<List<LookupItem>> reservationStatuses() =>
      _all('/reservation-statuses');

  Future<List<LookupItem>> roles() => _all('/roles');

  Future<LookupItem> addCity({
    required String name,
    required int countryId,
  }) async {
    final JsonMap body = await _client.post(
      '/cities',
      body: <String, dynamic>{'name': name, 'countryId': countryId},
    );

    return LookupItem.fromJson(body);
  }

  Future<List<LookupItem>> _all(String path, {JsonMap? query}) =>
      readEveryPage<LookupItem>(
        _client,
        path,
        read: LookupItem.fromJson,
        query: query,
      );
}
