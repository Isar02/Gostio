import 'package:gostio_core/gostio_core.dart';

class MessagesRepository {
  const MessagesRepository(this._client);

  final ApiClient _client;

  // The API answers newest first, so the pages after the first are what was
  // said before.
  Future<PagedResult<Message>> search({
    required int conversationId,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/conversations/$conversationId/messages',
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<Message>.fromJson(
      body,
      (Object? item) => Message.fromJson(item! as JsonMap),
    );
  }

  Future<Message> send({
    required int conversationId,
    required String body,
  }) async => Message.fromJson(
    await _client.post(
      '/conversations/$conversationId/messages',
      body: <String, dynamic>{'body': body},
    ),
  );

  // Both of these answer what the account has waiting across every thread,
  // which is the figure the tab draws.
  Future<int> markRead(int conversationId) async =>
      _unread(await _client.post('/conversations/$conversationId/read'));

  Future<int> unreadCount() async =>
      _unread(await _client.get('/conversations/unread-count'));

  static int _unread(JsonMap body) => body['unread'] as int? ?? 0;
}
