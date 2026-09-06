import 'package:gostio_core/gostio_core.dart';

// What this account has kept. One route answers both catalogues, newest first
// as the server orders it, so a saved stay and a saved term arrive in the
// order they were saved rather than in two lists to be merged here.
//
// Saving and unsaving are writes against the listing and stay where the heart
// is, which is the listing's own screen.
class FavoritesRepository {
  const FavoritesRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Favorite>> saved({
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/favorites',
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<Favorite>.fromJson(
      body,
      (Object? item) => Favorite.fromJson(item! as JsonMap),
    );
  }
}
