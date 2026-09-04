import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/conversation_query.dart';
import '../data/conversations_repository.dart';

// The hub carries one thread rather than a list, so the inbox reads itself
// again on a timer. Nothing here is refreshed by hand.
class InboxNotifier extends PagedNotifier<Conversation, ConversationQuery> {
  InboxNotifier(this._conversations, {required ConversationQuery query})
    : super(query) {
    _refresh = Timer.periodic(refreshInterval, (Timer _) => refreshQuietly());
  }

  static const Duration refreshInterval = Duration(seconds: 20);

  final ConversationsRepository _conversations;

  late final Timer _refresh;

  @override
  Future<PagedResult<Conversation>> fetch({
    required int page,
    required ConversationQuery query,
  }) => _conversations.search(query: query, page: page, pageSize: pageSize);

  Conversation? holding(int conversationId) {
    for (final Conversation thread in items) {
      if (thread.id == conversationId) {
        return thread;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _refresh.cancel();

    super.dispose();
  }
}
