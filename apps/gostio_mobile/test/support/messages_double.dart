import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/data/conversations_repository.dart';
import 'package:gostio_mobile/features/messages/data/messages_repository.dart';

import 'conversation_fixture.dart';

// The threads an inbox is drawn over. It pages what it was given the way the
// server would, so a test names rows rather than pages.
class ConversationsDouble implements ConversationsRepository {
  ConversationsDouble({this.rows = const <Conversation>[], this.failure});

  final List<Conversation> rows;
  final ApiException? failure;

  // What the server answers when a thread is read back after it was written
  // in. Left unset, the row already in the list is answered again.
  Conversation? readsBack;

  final List<int> pagesAsked = <int>[];
  final List<int> threadsRead = <int>[];

  @override
  Future<PagedResult<Conversation>> search({
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (failure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, rows.length);
    final int to = (from + pageSize).clamp(0, rows.length);

    return PagedResult<Conversation>(
      items: rows.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
    );
  }

  @override
  Future<Conversation> get(int conversationId) async {
    threadsRead.add(conversationId);

    if (readsBack case final Conversation answered) {
      return answered;
    }

    return rows.firstWhere(
      (Conversation held) => held.id == conversationId,
      orElse: () => thread(id: conversationId),
    );
  }
}

// The four calls a thread and the count over the tab are made of.
class MessagesDouble implements MessagesRepository {
  MessagesDouble({
    this.lines = const <Message>[],
    this.unread = 0,
    this.failure,
    this.sendFailure,
    this.holdsTheSend = false,
  });

  // Newest first, which is the order the API answers them in.
  final List<Message> lines;
  final int unread;

  final ApiException? failure;
  final ApiException? sendFailure;

  // A send that does not answer until a test says so, which is how a thread is
  // looked at while it is sending.
  final bool holdsTheSend;

  final Completer<void> _sent = Completer<void>();

  int countCalls = 0;
  int nextId = 900;
  final List<int> pagesAsked = <int>[];
  final List<String> bodiesSent = <String>[];
  final List<int> markedRead = <int>[];

  void answerSend() => _sent.complete();

  @override
  Future<PagedResult<Message>> search({
    required int conversationId,
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (failure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, lines.length);
    final int to = (from + pageSize).clamp(0, lines.length);

    return PagedResult<Message>(
      items: lines.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: lines.length,
    );
  }

  @override
  Future<Message> send({
    required int conversationId,
    required String body,
  }) async {
    if (holdsTheSend) {
      await _sent.future;
    }

    bodiesSent.add(body);

    if (sendFailure case final ApiException refused) {
      throw refused;
    }

    return line(
      id: nextId++,
      conversationId: conversationId,
      senderUserId: reader,
      senderName: 'Emina Begić',
      body: body,
      sentAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<int> markRead(int conversationId) async {
    markedRead.add(conversationId);

    return 0;
  }

  @override
  Future<int> unreadCount() async {
    countCalls++;

    if (failure case final ApiException refused) {
      throw refused;
    }

    return unread;
  }
}
