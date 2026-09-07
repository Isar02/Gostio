import 'package:gostio_core/gostio_core.dart';

// What the bell reads, what marking a notice read writes, and where this
// device says it can be reached. The last of those is not a screen's
// vocabulary, but it is the same feature and the same route, so it is here
// rather than behind a second seam onto one controller.
class NotificationsRepository {
  const NotificationsRepository(this._client);

  // This client is Android and registers as nothing else, so the platform it
  // names is a constant rather than something a caller decides.
  static const String _platform = 'Android';

  static const String _notifications = '/notifications';

  final ApiClient _client;

  Future<int> unreadCount() async {
    final JsonMap body = await _client.get('$_notifications/unread-count');

    return body['unread'] as int? ?? 0;
  }

  Future<PagedResult<AppNotification>> search({
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      _notifications,
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<AppNotification>.fromJson(
      body,
      (Object? item) => AppNotification.fromJson(item! as JsonMap),
    );
  }

  // Answers the row rather than a count, so the list draws what the server
  // holds instead of a mark this client made itself.
  Future<AppNotification> markRead(int id) async =>
      AppNotification.fromJson(await _client.post('$_notifications/$id/read'));

  // Answers what is left unread, which is the figure the bell draws.
  Future<int> markAllRead() async {
    final JsonMap body = await _client.post('$_notifications/read');

    return body['unread'] as int? ?? 0;
  }

  // Neither call names an account. A notice's owner comes off the token, and a
  // device registered by somebody else moves to this caller rather than being
  // held by both.
  Future<void> registerDevice(String token) => _client.postNoContent(
    '$_notifications/device-tokens',
    body: <String, String>{'token': token, 'platform': _platform},
  );

  Future<void> forgetDevice(String token) => _client.delete(
    '$_notifications/device-tokens',
    body: <String, String>{'token': token, 'platform': _platform},
  );
}
