import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'lookup_item.dart';

class ReferenceRepository {
  const ReferenceRepository(this._client);

  // The ceiling the API enforces on a page, which is what a caller reading a
  // whole table asks for.
  static const int _pageSize = 100;

  final ApiClient _client;

  Future<List<LookupItem>> cities() => _all('/cities');

  Future<List<LookupItem>> accommodationTypes() => _all('/accommodation-types');

  Future<List<LookupItem>> accommodationCategories() =>
      _all('/accommodation-categories');

  Future<List<LookupItem>> amenities() => _all('/amenities');

  // A dropdown is filled from the whole table rather than from its first page.
  Future<List<LookupItem>> _all(String path) async {
    final List<LookupItem> items = <LookupItem>[];

    for (int page = 1; ; page++) {
      final PagedResult<LookupItem> fetched = await _page(path, page);
      items.addAll(fetched.items);

      if (fetched.items.isEmpty || items.length >= fetched.totalCount) {
        return items;
      }
    }
  }

  Future<PagedResult<LookupItem>> _page(String path, int page) async {
    final JsonMap body = await _client.get(
      path,
      query: <String, dynamic>{'page': page, 'pageSize': _pageSize},
    );

    return PagedResult<LookupItem>.fromJson(
      body,
      (Object? item) => LookupItem.fromJson(item! as JsonMap),
    );
  }
}
