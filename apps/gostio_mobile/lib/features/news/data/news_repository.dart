import 'package:gostio_core/gostio_core.dart';

// What the platform publishes. A row carries its whole article, so the list is
// the only read: the screen an article opens on is drawn from the row the list
// handed it rather than asking for the same words a second time. The picture is
// an address on that row and is the one thing fetched separately.
class NewsRepository {
  const NewsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<NewsItem>> search({
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/news',
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<NewsItem>.fromJson(
      body,
      (Object? item) => NewsItem.fromJson(item! as JsonMap),
    );
  }
}
