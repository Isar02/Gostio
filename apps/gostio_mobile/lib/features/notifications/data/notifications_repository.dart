import 'package:gostio_core/gostio_core.dart';

// What the bell reads. The count is a route of its own because it is polled,
// and a page of rows is an expensive way to answer how many are unread.
class NotificationsRepository {
  const NotificationsRepository(this._client);

  final ApiClient _client;

  Future<int> unreadCount() async {
    final JsonMap body = await _client.get('/notifications/unread-count');

    return body['unread'] as int? ?? 0;
  }

  Future<PagedResult<AppNotification>> search({
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/notifications',
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<AppNotification>.fromJson(
      body,
      (Object? item) => AppNotification.fromJson(item! as JsonMap),
    );
  }
}
