import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/chat_hub.dart';
import '../data/conversation_query.dart';
import '../data/conversations_repository.dart';

// The hub says when a thread this account is in has been spoken in; the timer
// is what catches up when the socket is not there.
class InboxNotifier extends PagedNotifier<Conversation, ConversationQuery> {
  InboxNotifier(
    this._conversations, {
    required ConversationQuery query,
    ChatHub? hub,
  }) : super(query) {
    _listening = hub?.watchAccount().listen((int _) => refreshQuietly());
    _refresh = Timer.periodic(refreshInterval, (Timer _) => refreshQuietly());
  }

  static const Duration refreshInterval = Duration(seconds: 20);

  final ConversationsRepository _conversations;

  late final Timer _refresh;
  StreamSubscription<int>? _listening;

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
    unawaited(_listening?.cancel());

    super.dispose();
  }
}
