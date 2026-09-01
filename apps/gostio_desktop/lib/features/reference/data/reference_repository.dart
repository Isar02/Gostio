import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import 'lookup_item.dart';

class ReferenceRepository {
  const ReferenceRepository(this._client);

  final ApiClient _client;

  Future<List<LookupItem>> countries() => _all('/countries');

  Future<List<LookupItem>> cities() => _all('/cities');

  Future<List<LookupItem>> accommodationTypes() => _all('/accommodation-types');

  Future<List<LookupItem>> accommodationCategories() =>
      _all('/accommodation-categories');

  Future<List<LookupItem>> experienceCategories() =>
      _all('/experience-categories');

  Future<List<LookupItem>> amenities() => _all('/amenities');

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

  Future<List<LookupItem>> _all(String path) =>
      readEveryPage<LookupItem>(_client, path, read: LookupItem.fromJson);
}
