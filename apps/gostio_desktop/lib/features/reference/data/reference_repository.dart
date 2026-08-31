import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import 'lookup_item.dart';

class ReferenceRepository {
  const ReferenceRepository(this._client);

  final ApiClient _client;

  Future<List<LookupItem>> cities() => _all('/cities');

  Future<List<LookupItem>> accommodationTypes() => _all('/accommodation-types');

  Future<List<LookupItem>> accommodationCategories() =>
      _all('/accommodation-categories');

  Future<List<LookupItem>> amenities() => _all('/amenities');

  Future<List<LookupItem>> _all(String path) =>
      readEveryPage<LookupItem>(_client, path, read: LookupItem.fromJson);
}
