import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gostio_core/gostio_core.dart';

import 'live_notifier.dart';

// A figure the whole client draws, counted for the account rather than for the
// screen showing it. Two of them are drawn today — what is waiting behind the
// bell and what is waiting in the inbox — and both are counted the same way,
// so the counting is here and a subclass names only the route it reads.
//
// It is polled while the application is in front of the reader and left alone
// behind it: a phone nobody is looking at is told by push instead, and a timer
// running in the background spends battery to learn nothing.
abstract class UnreadCount extends LiveNotifier with WidgetsBindingObserver {
  UnreadCount() {
    WidgetsBinding.instance.addObserver(this);
    _watch();
  }

  static const Duration pollInterval = Duration(seconds: 30);

  Timer? _poll;
  int _unread = 0;
  int _request = 0;

  int get unread => _unread;

  @protected
  Future<int> read();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch();
    } else {
      _stop();
    }
  }

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

  // What a write has just answered. Marking a thread read costs the server the
  // same figure, so it is taken from there rather than asked for again.
  void report(int unread) => _write(++_request, unread);

  // Only the newest answer may write: one still in flight when a later one is
  // issued is stale by the time it lands.
  void _write(int request, int unread) {
    if (request == _request && unread != _unread && !isDisposed) {
      _unread = unread;
      publish();
    }
  }

  // Coming back to the foreground asks at once rather than waiting out the
  // interval, because what arrived while the application was away is the
  // reason the reader opened it.
  void _watch() {
    _poll ??= Timer.periodic(pollInterval, (Timer _) => refresh());
    unawaited(refresh());
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();

    super.dispose();
  }
}
