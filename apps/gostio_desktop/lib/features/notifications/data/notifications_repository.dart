import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository(this._client);

  final ApiClient _client;

  Future<int> unreadCount() async =>
      _unread(await _client.get('/notifications/unread-count'));

  Future<PagedResult<AppNotification>> search({
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    bool? isRead,
  }) async {
    final JsonMap body = await _client.get(
      '/notifications',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'isRead': ?isRead,
      },
    );

    return PagedResult<AppNotification>.fromJson(
      body,
      (Object? item) => AppNotification.fromJson(item! as JsonMap),
    );
  }

  Future<void> markRead(int id) async {
    await _client.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.post('/notifications/read');
  }

  static int _unread(JsonMap body) => body['unread'] as int? ?? 0;
}
