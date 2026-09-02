import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import '../../listings/data/listing_address.dart';
import '../../listings/data/listing_titles.dart';
import '../../reference/data/lookup_item.dart';
import 'accommodation.dart';
import 'accommodation_draft.dart';
import 'accommodation_query.dart';

class AccommodationsRepository {
  const AccommodationsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    final JsonMap body = await _client.get(
      '/accommodations',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'hostId': ?hostId,
        ...query.toParameters(),
      },
    );

    return PagedResult<Accommodation>.fromJson(
      body,
      (Object? item) => Accommodation.fromJson(item! as JsonMap),
    );
  }

  Future<Accommodation> get(int id) async =>
      Accommodation.fromJson(await _client.get('/accommodations/$id'));

  Future<List<LookupItem>> titles({int? hostId}) =>
      readListingTitles(_client, ListingKind.accommodation, hostId: hostId);

  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) async =>
      Accommodation.fromJson(
        await _client.post(
          '/accommodations',
          body: draft.toCreate(hostId: hostId),
        ),
      );

  Future<Accommodation> update(
    int id,
    AccommodationDraft draft, {
    required bool isActive,
  }) async => Accommodation.fromJson(
    await _client.put(
      '/accommodations/$id',
      body: draft.toUpdate(isActive: isActive),
    ),
  );

  Future<void> delete(int id) => _client.delete('/accommodations/$id');
}
