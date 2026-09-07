import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import 'foreground_poll.dart';
import 'live_notifier.dart';

// A figure the whole client draws, counted for the account rather than for the
// screen showing it. Two of them are drawn today — what is waiting behind the
// bell and what is waiting in the inbox — and both are counted the same way,
// so the counting is here and a subclass names only the route it reads.
//
// When it is read, and when it stops being read, is `ForegroundPoll`'s.
abstract class UnreadCount extends LiveNotifier {
  UnreadCount() {
    _poll = ForegroundPoll(refresh);
    unawaited(refresh());
  }

  late final ForegroundPoll _poll;

  int _unread = 0;
  int _request = 0;

  int get unread => _unread;

  @protected
  Future<int> read();

  // A refusal leaves the figure as it stands. Neither count is the surface a
  // network fault is worth reporting on, and the next poll says so anyway.
  Future<void> refresh() async {
    final int request = ++_request;

    try {
      _write(request, await read());
    } on ApiException {
      return;
    }
  }

  // A write is registered when it starts, not when its answer happens to
  // arrive. Otherwise an older, slow mark-read answer could overwrite a poll
  // that began later and already saw a newly arrived message.
  Future<void> report(Future<int> answer) async {
    final int request = ++_request;

    _write(request, await answer);
  }

  // Only the newest answer may write: one still in flight when a later one is
  // issued is stale by the time it lands.
  void _write(int request, int unread) {
    if (request == _request && unread != _unread && !isDisposed) {
      _unread = unread;
      publish();
    }
  }

  @override
  void dispose() {
    _poll.dispose();

    super.dispose();
  }
}
