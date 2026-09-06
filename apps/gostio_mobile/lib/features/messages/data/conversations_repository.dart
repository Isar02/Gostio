import 'package:gostio_core/gostio_core.dart';

// The threads this account is in. The API answers a caller only what they are
// a party to, so nothing here narrows by who is in it.
class ConversationsRepository {
  const ConversationsRepository(this._client);

  final ApiClient _client;

  // Newest activity first, which is the order an inbox is read in.
  Future<PagedResult<Conversation>> search({
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/conversations',
      query: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );

    return PagedResult<Conversation>.fromJson(
      body,
      (Object? item) => Conversation.fromJson(item! as JsonMap),
    );
  }

  Future<Conversation> get(int conversationId) async => Conversation.fromJson(
    await _client.get('/conversations/$conversationId'),
  );
}
