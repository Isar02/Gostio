import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';

class ReservationsRepository {
  const ReservationsRepository(this._client);

  final ApiClient _client;

  // Only the count is wanted, so the smallest page the API allows is asked for
  // and the rows it answers with are thrown away.
  Future<int> countForAccommodation(int accommodationId) async {
    final JsonMap body = await _client.get(
      '/reservations',
      query: <String, dynamic>{
        'accommodationId': accommodationId,
        'page': 1,
        'pageSize': 1,
      },
    );

    return PagedResult<Object?>.fromJson(
      body,
      (Object? item) => item,
    ).totalCount;
  }
}
