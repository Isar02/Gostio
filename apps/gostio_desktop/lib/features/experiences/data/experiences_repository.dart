import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import '../../listings/data/listing_address.dart';
import '../../listings/data/listing_titles.dart';
import '../../reference/data/lookup_item.dart';
import 'experience.dart';
import 'experience_draft.dart';
import 'experience_query.dart';

class ExperiencesRepository {
  const ExperiencesRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    final JsonMap body = await _client.get(
      '/experiences',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'hostId': ?hostId,
        ...query.toParameters(),
      },
    );

    return PagedResult<Experience>.fromJson(
      body,
      (Object? item) => Experience.fromJson(item! as JsonMap),
    );
  }

  Future<Experience> get(int id) async =>
      Experience.fromJson(await _client.get('/experiences/$id'));

  Future<List<LookupItem>> titles({int? hostId}) =>
      readListingTitles(_client, ListingKind.experience, hostId: hostId);

  Future<Experience> create(ExperienceDraft draft, {int? hostId}) async =>
      Experience.fromJson(
        await _client.post(
          '/experiences',
          body: draft.toCreate(hostId: hostId),
        ),
      );

  Future<Experience> update(
    int id,
    ExperienceDraft draft, {
    required bool isActive,
  }) async => Experience.fromJson(
    await _client.put(
      '/experiences/$id',
      body: draft.toUpdate(isActive: isActive),
    ),
  );

  Future<void> delete(int id) => _client.delete('/experiences/$id');
}
