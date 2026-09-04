import 'package:gostio_core/gostio_core.dart';

class MessagesRepository {
  const MessagesRepository(this._client);

  final ApiClient _client;

  // The API answers newest first, so the pages after the first are what came
  // before.
  Future<PagedResult<Message>> search({
    required int conversationId,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
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

  Future<int> markRead(int conversationId) async =>
      _unread(await _client.post('/conversations/$conversationId/read'));

  Future<int> unreadCount() async =>
      _unread(await _client.get('/conversations/unread-count'));

  static int _unread(JsonMap body) => body['unread'] as int? ?? 0;
}
