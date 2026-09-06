import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/conversations_repository.dart';

// Every thread this account is in, newest activity first. It has no filter of
// its own — a guest reaches only their own threads — so the query it pages
// under carries nothing.
class InboxNotifier extends PagedNotifier<Conversation, void> {
  InboxNotifier(this._repository) : super(null) {
    unawaited(reload());
  }

  final ConversationsRepository _repository;

  // What the list is holding, in the order the server keeps it: last spoken in
  // first, and the newer thread first where two were spoken in at once. Every
  // page arrives in that order, and the only row that can leave it is one the
  // reader has just been in — so the server's own key is applied again to the
  // rows in hand rather than the whole list being read a second time to move
  // one of them.
  List<Conversation> get threads =>
      List<Conversation>.of(items)..sort(_lastSpokenInFirst);

  @override
  @protected
  Future<PagedResult<Conversation>> fetch({
    required int page,
    required void query,
  }) => _repository.search(page: page, pageSize: pageSize);

  // The thread as the server holds it once the reader has been in it: read,
  // and carrying whatever was said while they were there. The list keeps the
  // pages it has already read and redraws the one row that changed.
  void threadChanged(Conversation thread) =>
      replaceWhere((Conversation held) => held.id == thread.id, thread);

  static int _lastSpokenInFirst(Conversation one, Conversation other) {
    final int moment = other.lastActivityAt.compareTo(one.lastActivityAt);

    return moment != 0 ? moment : other.id.compareTo(one.id);
  }
}
