import 'package:gostio_core/gostio_core.dart';

// What the server suggests to this account, ranked best first.
//
// The catalogue is required rather than optional. A suggestion is scored
// against the whole of one catalogue before a page is cut out of it, so stays
// and terms are two rankings and never one list — which is the opposite of
// what the saved listings are, and for the same reason: there the order is the
// order they were saved in.
class RecommendationsRepository {
  const RecommendationsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Recommendation>> picks({
    required ListingKind catalogue,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/recommendations',
      query: <String, dynamic>{
        'target': catalogue.catalogueName,
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Recommendation>.fromJson(
      body,
      (Object? item) => Recommendation.fromJson(item! as JsonMap),
    );
  }
}
