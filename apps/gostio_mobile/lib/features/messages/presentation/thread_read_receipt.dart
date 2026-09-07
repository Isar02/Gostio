import 'package:gostio_core/gostio_core.dart';

import '../data/conversations_repository.dart';
import '../data/messages_repository.dart';

// Marks one thread read and carries the resulting row and account count back
// to their owners. Repeated requests share one drain: another mark made while
// one is running is performed after the current row has been read back.
class ThreadReadReceipt {
  ThreadReadReceipt(
    this._messages,
    this._conversations, {
    required this.conversationId,
    required this.onThread,
    this.onUnread,
  });

  final MessagesRepository _messages;
  final ConversationsRepository _conversations;
  final int conversationId;
  final void Function(Conversation thread) onThread;
  final Future<void> Function(Future<int> unread)? onUnread;

  Future<void>? _running;
  bool _again = false;
  bool _isDisposed = false;

  Future<void> markRead() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _again = true;
    if (_running case final Future<void> running) {
      return running;
    }

    late final Future<void> running;
    running = _drain().whenComplete(() {
      if (identical(_running, running)) {
        _running = null;
      }
    });
    _running = running;

    return running;
  }

  Future<void> _drain() async {
    while (_again && !_isDisposed) {
      _again = false;
      await _write();
      await _readThread();
    }
  }

  Future<void> _write() async {
    try {
      // Start the write before the optional callback is consulted. The count
      // registers that future immediately, so a later poll keeps precedence.
      final Future<int> marking = _messages.markRead(conversationId);
      final Future<void> Function(Future<int>)? report = onUnread;
      if (report == null) {
        await marking;
      } else {
        await report(marking);
      }
    } on ApiException {
      // The row is still read back: sending changed it even if its read mark
      // was refused, and this helper is not the surface for that refusal.
    }
  }

  Future<void> _readThread() async {
    try {
      final Conversation read = await _conversations.get(conversationId);
      if (!_isDisposed) {
        onThread(read);
      }
    } on ApiException {
      // This follow-up read is silent; no reader requested it directly.
    }
  }

  void dispose() {
    _isDisposed = true;
    _again = false;
  }
}
