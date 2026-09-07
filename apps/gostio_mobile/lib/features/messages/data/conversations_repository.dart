import 'package:gostio_core/gostio_core.dart';

import 'thread_subject.dart';

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

  // Opening a thread that already stands answers with it rather than refusing,
  // so this asks without first knowing whether there is one. Every way into a
  // thread comes through here and each answers the thread to read.
  Future<Conversation> open(ThreadSubject subject) async =>
      Conversation.fromJson(await switch (subject) {
        WithHost(:final int hostId) => _client.post(
          '/conversations',
          body: <String, dynamic>{'withUserId': hostId},
        ),
        AboutBooking(:final int reservationId) => _client.post(
          '/conversations',
          body: <String, dynamic>{'reservationId': reservationId},
        ),
        WithSupport() => _client.post('/conversations/support'),
      });
}
