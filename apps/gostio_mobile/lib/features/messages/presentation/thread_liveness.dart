import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/chat_hub.dart';

// The lifetime of the one live thread connection. A thread without the socket
// keeps itself current on a timer; a joined one stops that timer. The stream
// may also be closed because another thread replaced it, which is the same as
// losing the socket and must restart the fallback.
class ThreadLiveness with WidgetsBindingObserver {
  ThreadLiveness(
    this._hub, {
    required this.conversationId,
    required this.onEvent,
    required this.onRefresh,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const Duration refreshInterval = Duration(seconds: 15);

  final ChatHub _hub;
  final int conversationId;
  final void Function(ChatEvent event) onEvent;
  final Future<void> Function() onRefresh;

  StreamSubscription<ChatEvent>? _listening;
  Timer? _refresh;
  bool _isLive = false;
  bool _isDisposed = false;

  void start() {
    if (!_isDisposed) {
      _watch();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch();
    } else {
      _release();
    }
  }

  void _watch() {
    if (_isDisposed || _listening != null) {
      return;
    }

    late final StreamSubscription<ChatEvent> listening;
    listening = _hub
        .watch(conversationId)
        .listen(_heard, onDone: () => _ended(listening));
    _listening = listening;
    _startRefreshing();
  }

  void _heard(ChatEvent event) {
    switch (event) {
      case ChatJoined():
        _isLive = true;
        _stopRefreshing();
      case ChatDropped():
        _isLive = false;
        _startRefreshing();
      case ChatSaid():
        break;
    }

    onEvent(event);
  }

  // Replacing this watch closes its stream without sending a dropped event.
  // Clear the finished subscription and fall back to reads just as a dropped
  // connection would.
  void _ended(StreamSubscription<ChatEvent> listening) {
    if (_isDisposed || !identical(_listening, listening)) {
      return;
    }

    _listening = null;
    _isLive = false;
    _startRefreshing();
  }

  void _startRefreshing() {
    if (_isDisposed || _isLive) {
      return;
    }

    _refresh ??= Timer.periodic(
      refreshInterval,
      (Timer _) => unawaited(onRefresh()),
    );
  }

  void _stopRefreshing() {
    _refresh?.cancel();
    _refresh = null;
  }

  void _release() {
    final StreamSubscription<ChatEvent>? listening = _listening;
    _listening = null;
    _isLive = false;
    _stopRefreshing();
    unawaited(listening?.cancel());
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _release();
  }
}
