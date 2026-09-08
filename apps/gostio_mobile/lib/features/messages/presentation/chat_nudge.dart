import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/chat_hub.dart';

// The one account-wide socket, held while the client is in front of its reader
// and dropped behind it, the same rule `ForegroundPoll` follows. What it hands
// out is the id of a thread that has just been spoken in; the tab badge and the
// inbox read again on it rather than waiting for their interval.
class ChatNudge with WidgetsBindingObserver {
  ChatNudge(this._hub) {
    WidgetsBinding.instance.addObserver(this);

    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _watch();
    }
  }

  final ChatHub _hub;
  final StreamController<int> _touched = StreamController<int>.broadcast();

  StreamSubscription<int>? _listening;
  bool _isDisposed = false;

  Stream<int> get touched => _touched.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch();
    } else {
      _release();
    }
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    unawaited(_touched.close());
  }

  void _watch() {
    if (_isDisposed || _listening != null) {
      return;
    }

    _listening = _hub.watchAccount().listen(_heard);
  }

  void _heard(int conversationId) {
    if (!_touched.isClosed) {
      _touched.add(conversationId);
    }
  }

  void _release() {
    unawaited(_listening?.cancel());
    _listening = null;
  }
}
