import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/paged_result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../data/chat_hub.dart';
import '../data/message.dart';
import '../data/messages_repository.dart';

class ThreadNotifier extends ScreenNotifier {
  ThreadNotifier(
    this._messages,
    this._hub, {
    required this.conversationId,
    required this.callerId,
    this.onRead,
  });

  static const Duration refreshInterval = Duration(seconds: 15);

  final MessagesRepository _messages;
  final ChatHub _hub;

  final int conversationId;
  final int callerId;

  final ValueChanged<int>? onRead;

  final List<Message> _lines = <Message>[];
  final Set<int> _held = <int>{};

  StreamSubscription<ChatEvent>? _listening;
  Timer? _refresh;

  bool _isLoading = true;
  bool _isReadingEarlier = false;
  bool _isRefreshing = false;
  bool _isSending = false;
  bool _isLive = false;
  bool _isMarkingRead = false;
  bool _readAgain = false;
  int _pagesRead = 0;
  int _totalCount = 0;
  String? _lostLive;
  ApiException? _failure;
  ApiException? _sendFailure;

  List<Message> get lines => _lines;

  bool get isLoading => _isLoading;

  bool get isReadingEarlier => _isReadingEarlier;

  bool get isSending => _isSending;

  bool get isLive => _isLive;

  String? get liveFailureMessage => _lostLive;

  bool get hasEarlier => _lines.length < _totalCount;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  // A refusal that names the field is said under the box rather than above it.
  String? get sendFailureMessage => switch (_sendFailure) {
    final ApiException refused when !refused.faultsAField => refused.message,
    _ => null,
  };

  String? messageFor(String field) => _sendFailure?.firstMessageFor(field);

  Future<void> open() async {
    _listening ??= _hub.watch(conversationId).listen(_heard);

    _startRefreshing();

    await _read(page: 1);
    await _markRead();
  }

  Future<void> readEarlier() async {
    if (_isReadingEarlier || !hasEarlier) {
      return;
    }

    _isReadingEarlier = true;
    publish();

    await _read(page: _pagesRead + 1);

    _isReadingEarlier = false;
    publish();
  }

  Future<bool> send(String body) async {
    _isSending = true;
    _sendFailure = null;
    publish();

    try {
      _hold(await _messages.send(conversationId: conversationId, body: body));
    } on ApiException catch (refused) {
      _sendFailure = refused;
      _isSending = false;
      publish();

      return false;
    }

    _isSending = false;
    publish();

    // Answering is reading, and on a support thread it also joins it.
    await _markRead();

    return true;
  }

  void _heard(ChatEvent event) {
    switch (event) {
      case ChatJoined():
        _isLive = true;
        _lostLive = null;
        _stopRefreshing();
        publish();
      case ChatDropped(:final String reason):
        _isLive = false;
        _lostLive = reason;
        _startRefreshing();
        publish();
      case ChatSaid(:final Message message):
        if (message.conversationId != conversationId || !_hold(message)) {
          return;
        }

        publish();

        if (message.senderUserId != callerId) {
          unawaited(_markRead());
        }
    }
  }

  Future<void> _read({required int page}) async {
    _isLoading = _lines.isEmpty;
    _failure = null;
    publish();

    try {
      final PagedResult<Message> read = await _messages.search(
        conversationId: conversationId,
        page: page,
      );

      if (isDisposed) {
        return;
      }

      for (final Message line in read.items) {
        _hold(line);
      }

      _totalCount = read.totalCount;
      _pagesRead = page > _pagesRead ? page : _pagesRead;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<void> _refreshQuietly() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

    try {
      final PagedResult<Message> read = await _messages.search(
        conversationId: conversationId,
        page: 1,
      );

      if (isDisposed) {
        return;
      }

      var arrived = false;
      for (final Message line in read.items) {
        arrived = _hold(line) || arrived;
      }

      if (read.totalCount > _totalCount) {
        _totalCount = read.totalCount;
      }

      if (arrived) {
        publish();
        await _markRead();
      }
    } on ApiException {
      // Nobody asked for this read, so nobody is told it did not happen.
    } finally {
      _isRefreshing = false;
    }
  }

  bool _hold(Message message) {
    if (!_held.add(message.id)) {
      return false;
    }

    var at = _lines.length;
    while (at > 0 && _isAfter(_lines[at - 1], message)) {
      at--;
    }

    _lines.insert(at, message);

    if (at == _lines.length - 1 && _pagesRead > 0) {
      _totalCount++;
    }

    return true;
  }

  Future<void> _markRead() async {
    if (_isMarkingRead) {
      _readAgain = true;

      return;
    }

    _isMarkingRead = true;
    _readAgain = false;

    try {
      // Inside the callback this would be short-circuited away with it.
      final int unread = await _messages.markRead(conversationId);

      onRead?.call(unread);
    } on ApiException {
      _readAgain = false;
    } finally {
      _isMarkingRead = false;
    }

    if (_readAgain && !isDisposed) {
      await _markRead();
    }
  }

  void _startRefreshing() {
    _refresh ??= Timer.periodic(
      refreshInterval,
      (Timer _) => unawaited(_refreshQuietly()),
    );
  }

  void _stopRefreshing() {
    _refresh?.cancel();
    _refresh = null;
  }

  static bool _isAfter(Message one, Message other) =>
      one.sentAt.isAfter(other.sentAt) ||
      (one.sentAt == other.sentAt && one.id > other.id);

  @override
  void dispose() {
    _stopRefreshing();
    unawaited(_listening?.cancel());
    _listening = null;

    super.dispose();
  }
}
