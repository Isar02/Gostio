import 'dart:async';

import '../../../core/state/unread_count.dart';
import '../data/messages_repository.dart';
import 'chat_nudge.dart';

// What is waiting in the inbox, drawn over the tab from wherever the reader
// is. It is read once for the whole client rather than once per tab, and a
// thread marked read hands it the figure the server answered.
class UnreadMessages extends UnreadCount {
  UnreadMessages(this._repository, {ChatNudge? nudge}) {
    _listening = nudge?.touched.listen((int _) => unawaited(refresh()));
  }

  final MessagesRepository _repository;

  StreamSubscription<int>? _listening;

  @override
  Future<int> read() => _repository.unreadCount();

  @override
  void dispose() {
    unawaited(_listening?.cancel());

    super.dispose();
  }
}
