import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/messages/data/conversation_query.dart';
import 'package:gostio_desktop/features/messages/data/conversations_repository.dart';
import 'package:gostio_desktop/features/messages/data/messages_repository.dart';

// What the inbox asked for and what it was told.
class ConversationsDouble implements ConversationsRepository {
  ConversationsDouble({
    this.rows = const <Conversation>[],
    int? totalCount,
    this.failing = false,
  }) : totalCount = totalCount ?? rows.length;

  List<Conversation> rows;
  int totalCount;
  bool failing;

  final List<int> pages = <int>[];
  final List<ConversationQuery> queries = <ConversationQuery>[];

  @override
  Future<PagedResult<Conversation>> search({
    required ConversationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pages.add(page);
    queries.add(query);

    if (failing) {
      throw const ApiException(
        message: 'The threads could not be read.',
        traceId: 'c3d9f1',
      );
    }

    return PagedResult<Conversation>(
      items: rows,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<Conversation> get(int id) async {
    if (failing) {
      throw const ApiException(message: 'The thread could not be read.');
    }

    return rows.firstWhere((Conversation row) => row.id == id);
  }
}

// A thread's own messages: what was read out of it, what was written into it,
// and what the marking answered with.
class MessagesDouble implements MessagesRepository {
  MessagesDouble({
    this.pagesOfLines = const <List<Message>>[],
    int? totalCount,
    this.unread = 0,
    this.refusing,
    this.failing = false,
  }) : totalCount =
           totalCount ??
           pagesOfLines.fold(
             0,
             (int counted, List<Message> page) => counted + page.length,
           );

  List<List<Message>> pagesOfLines;
  int totalCount;
  int unread;
  ApiException? refusing;
  bool failing;

  final List<int> pagesRead = <int>[];
  final List<String> written = <String>[];
  int markedRead = 0;

  Message Function(String body)? answers;

  @override
  Future<PagedResult<Message>> search({
    required int conversationId,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pagesRead.add(page);

    if (failing) {
      throw const ApiException(
        message: 'The thread could not be read.',
        traceId: '7f2a10',
      );
    }

    return PagedResult<Message>(
      items: page <= pagesOfLines.length
          ? pagesOfLines[page - 1]
          : const <Message>[],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<Message> send({
    required int conversationId,
    required String body,
  }) async {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    written.add(body);

    return answers?.call(body) ??
        Message(
          id: 900 + written.length,
          conversationId: conversationId,
          senderUserId: 1,
          senderName: 'Dina Kovačević',
          body: body,
          sentAt: DateTime.utc(2026, 8, 28, 12, written.length),
        );
  }

  @override
  Future<int> markRead(int conversationId) async {
    markedRead++;

    if (failing) {
      throw const ApiException(message: 'The thread could not be marked read.');
    }

    return unread;
  }

  @override
  Future<int> unreadCount() async {
    if (failing) {
      throw const ApiException(message: 'The count could not be read.');
    }

    return unread;
  }
}
