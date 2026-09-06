import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/conversations_repository.dart';
import '../data/messages_repository.dart';

// One thread being read: the lines in it, newest first as the API answers
// them, and the one being written. Earlier lines are a page further back
// rather than a page instead of this one, so the whole thread stays on screen
// once it has been read.
class ThreadNotifier extends LiveNotifier {
  ThreadNotifier(
    this._messages,
    this._conversations,
    this._thread, {
    required this.callerId,
    this.onThreadChanged,
    this.onUnread,
  });

  final MessagesRepository _messages;
  final ConversationsRepository _conversations;

  final int callerId;

  // The row the list this was opened from is showing, handed back whenever the
  // server has answered a newer one.
  final void Function(Conversation thread)? onThreadChanged;

  // What the account has waiting across every thread, which marking this one
  // read answers on the way.
  final void Function(int unread)? onUnread;

  final List<Message> _lines = <Message>[];
  final Set<int> _held = <int>{};

  Conversation _thread;
  bool _isLoading = true;
  bool _isReadingEarlier = false;
  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _readAgain = false;
  int _pagesRead = 0;
  int _totalCount = 0;
  ApiException? _failure;
  ApiException? _sendFailure;

  Conversation get thread => _thread;

  List<Message> get lines => _lines;

  bool get isLoading => _isLoading;

  bool get isReadingEarlier => _isReadingEarlier;

  bool get isSending => _isSending;

  bool get hasEarlier => _lines.length < _totalCount;

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
    await _read(page: 1);

    // Nothing is written where nothing is waiting: a thread the reader has
    // already seen through does not need to be marked read a second time.
    if (_thread.holdsUnread && !isDisposed) {
      await _markRead();
    }
  }

  Future<void> readEarlier() async {
    if (_isReadingEarlier || _isLoading || !hasEarlier) {
      return;
    }

    _isReadingEarlier = true;
    publish();

    await _read(page: _pagesRead + 1);

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
      _hold(await _messages.send(conversationId: _thread.id, body: body));
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
    await _markRead();

    return true;
  }

  Future<void> _read({required int page}) async {
    _isLoading = _lines.isEmpty;
    _failure = null;
    publish();

    try {
      final PagedResult<Message> read = await _messages.search(
        conversationId: _thread.id,
        page: page,
        pageSize: PagedResult.defaultPageSize,
      );

      if (isDisposed) {
        return;
      }

      for (final Message line in read.items) {
        _hold(line);
      }

      _totalCount = read.totalCount;
      _pagesRead = page > _pagesRead ? page : _pagesRead;
    } on ApiException catch (refused) {
      if (isDisposed) {
        return;
      }

      _failure = refused;
    }

    _isLoading = false;
    publish();
  }

  // Newest first, and each line filed once however many times it arrives: a
  // line sent is held by its answer and could be read again by the next page.
  bool _hold(Message message) {
    if (!_held.add(message.id)) {
      return false;
    }

    var at = 0;
    while (at < _lines.length && _isAfter(_lines[at], message)) {
      at++;
    }

    _lines.insert(at, message);

    // A line newer than everything already read is one the server had not
    // counted when it answered the page this list was built from.
    if (at == 0 && _pagesRead > 0) {
      _totalCount++;
    }

    return true;
  }

  // Several things ask for this — opening the thread, and every line sent — so
  // only one is out at a time and a request made while one is out is repeated
  // after it rather than raced against it.
  Future<void> _markRead() async {
    if (_isMarkingRead) {
      _readAgain = true;

      return;
    }

    _isMarkingRead = true;
    _readAgain = false;

    try {
      onUnread?.call(await _messages.markRead(_thread.id));
    } on ApiException {
      // The count stands as it was. The row is still read back afterwards,
      // because a line just sent has changed it whether or not the read mark
      // landed.
    } finally {
      _isMarkingRead = false;
    }

    await _readThread();

    if (_readAgain && !isDisposed) {
      await _markRead();
    }
  }

  // The row as the server then holds it. The list this thread was opened from
  // is showing the same row and read it before any of this happened.
  Future<void> _readThread() async {
    try {
      final Conversation read = await _conversations.get(_thread.id);

      if (isDisposed) {
        return;
      }

      _thread = read;
      onThreadChanged?.call(read);
      publish();
    } on ApiException {
      // Nobody asked for this read, so nobody is told it did not happen.
    }
  }

  static bool _isAfter(Message one, Message other) =>
      one.sentAt.isAfter(other.sentAt) ||
      (one.sentAt == other.sentAt && one.id > other.id);
}
