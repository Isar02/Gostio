import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'accommodation.dart';
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
}
