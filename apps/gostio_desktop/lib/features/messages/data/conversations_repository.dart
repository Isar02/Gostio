import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'conversation.dart';
import 'conversation_query.dart';

class ConversationsRepository {
  const ConversationsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Conversation>> search({
    required ConversationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/conversations',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<Conversation>.fromJson(
      body,
      (Object? item) => Conversation.fromJson(item! as JsonMap),
    );
  }

  Future<Conversation> get(int id) async =>
      Conversation.fromJson(await _client.get('/conversations/$id'));
}
