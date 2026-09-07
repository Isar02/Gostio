import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/chat_hub.dart';
import '../data/conversations_repository.dart';
import '../data/messages_repository.dart';
import 'thread_history.dart';
import 'thread_liveness.dart';
import 'thread_read_receipt.dart';

// One thread being read: the lines in it, newest first as the API answers
// them, and the one being written. Earlier lines are a page further back
// rather than a page instead of this one, so the whole thread stays on screen
// once it has been read.
//
// What arrives while the thread is open comes over the hub. The socket is held
// only while the application is in front of the reader: it is given up when the
// phone goes into a pocket and taken again when it comes back, and a thread
// with no socket reads its newest page on a timer instead. Neither state is
// announced, because both are the thread up to date within seconds and a
// sentence about the connection is not what the reader came to read.
class ThreadNotifier extends LiveNotifier {
  ThreadNotifier(
    this._messages,
    ConversationsRepository conversations,
    ChatHub hub,
    this._thread, {
    required this.callerId,
    this.onThreadChanged,
    Future<void> Function(Future<int> unread)? onUnread,
  }) {
    _liveness = ThreadLiveness(
      hub,
      conversationId: _thread.id,
      onEvent: _heard,
      onRefresh: _refreshQuietly,
    );
    _receipt = ThreadReadReceipt(
      _messages,
      conversations,
      conversationId: _thread.id,
      onThread: _acceptThread,
      onUnread: onUnread,
    );
  }

  final MessagesRepository _messages;

  final int callerId;

  // The row the list this was opened from is showing, handed back whenever the
  // server has answered a newer one.
  final void Function(Conversation thread)? onThreadChanged;

  final ThreadHistory _history = ThreadHistory();

  late final ThreadLiveness _liveness;
  late final ThreadReadReceipt _receipt;

  Conversation _thread;
  bool _isRefreshing = false;
  bool _isLoading = true;
  bool _isReadingEarlier = false;
  bool _isSending = false;
  bool _refreshAgain = false;
  ApiException? _failure;
  ApiException? _sendFailure;

  Conversation get thread => _thread;

  List<Message> get lines => _history.lines;

  bool get isLoading => _isLoading;

  bool get isReadingEarlier => _isReadingEarlier;

  bool get isSending => _isSending;

  bool get hasEarlier => _history.hasEarlier;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  // A refusal that faults the body is said under the box the body was typed
  // in; anything else is about the send rather than about what was typed.
  String? get sendFailureMessage => switch (_sendFailure) {
    final ApiException refused when !refused.faultsAField => refused.message,
    _ => null,
  };

  String? get bodyRefusal => _sendFailure?.firstMessageFor('body');

  Future<void> open() async {
    _liveness.start();

    await _read(page: 1);

    // Nothing is written where nothing is waiting: a thread the reader has
    // already seen through does not need to be marked read a second time.
    if (_thread.holdsUnread && !isDisposed) {
      await _receipt.markRead();
    }
  }

  Future<void> readEarlier() async {
    if (_isReadingEarlier || _isLoading || !hasEarlier) {
      return;
    }

    _isReadingEarlier = true;
    publish();

    await _read(page: _history.nextPage);

    if (!isDisposed) {
      _isReadingEarlier = false;
      publish();
    }
  }

  Future<bool> send(String body) async {
    _isSending = true;
    _sendFailure = null;
    publish();

    try {
      _history.add(
        await _messages.send(conversationId: _thread.id, body: body),
      );
    } on ApiException catch (refused) {
      if (!isDisposed) {
        _sendFailure = refused;
        _isSending = false;
        publish();
      }

      return false;
    }

    if (isDisposed) {
      return true;
    }

    _isSending = false;
    publish();

    // Answering is reading, and it is also what makes this thread's row say
    // what was last said in it.
    await _receipt.markRead();

    return true;
  }

  void bodyChanged() {
    if (_sendFailure == null || isDisposed) {
      return;
    }

    _sendFailure = null;
    publish();
  }

  Future<void> _read({required int page}) async {
    _isLoading = _history.lines.isEmpty;
    _failure = null;
    publish();

    try {
      final PagedResult<Message> read = await _fetchPage(page);

      if (isDisposed) {
        return;
      }

      _history.addPage(read);
    } on ApiException catch (refused) {
      if (isDisposed) {
        return;
      }

      _failure = refused;
    }

    _isLoading = false;
    publish();
    _repeatRefreshIfNeeded();
  }

  Future<PagedResult<Message>> _fetchPage(int page) => _messages.search(
    conversationId: _thread.id,
    page: page,
    pageSize: PagedResult.defaultPageSize,
  );

  void _acceptThread(Conversation read) {
    if (isDisposed) {
      return;
    }

    _thread = read;
    onThreadChanged?.call(read);
    publish();
  }

  void _heard(ChatEvent event) {
    switch (event) {
      case ChatJoined():
        // A connection made after something was said would never be told about
        // it, so the newest page is read again rather than trusted.
        unawaited(_refreshQuietly(repeatWhenBusy: true));
      case ChatDropped():
        break;
      case ChatSaid(:final Message message):
        if (message.conversationId != _thread.id || !_history.add(message)) {
          return;
        }

        publish();

        if (message.senderUserId != callerId) {
          unawaited(_receipt.markRead());
        }
    }
  }

  // Nobody asked for this read, so nobody is told it did not happen and the
  // thread is only redrawn where something actually arrived.
  Future<void> _refreshQuietly({bool repeatWhenBusy = false}) async {
    if (_isRefreshing || _isLoading) {
      _refreshAgain = _refreshAgain || repeatWhenBusy;

      return;
    }

    _isRefreshing = true;

    try {
      final PagedResult<Message> read = await _fetchPage(1);

      if (isDisposed) {
        return;
      }

      final List<Message> arrived = _history.refresh(read);

      if (arrived.isNotEmpty) {
        publish();
        if (arrived.any((Message line) => line.senderUserId != callerId)) {
          await _receipt.markRead();
        }
      }
    } on ApiException {
      return;
    } finally {
      _isRefreshing = false;
      _repeatRefreshIfNeeded();
    }
  }

  void _repeatRefreshIfNeeded() {
    if (!_refreshAgain || _isLoading || _isRefreshing || isDisposed) {
      return;
    }

    _refreshAgain = false;
    unawaited(_refreshQuietly(repeatWhenBusy: true));
  }

  @override
  void dispose() {
    _liveness.dispose();
    _receipt.dispose();

    super.dispose();
  }
}
