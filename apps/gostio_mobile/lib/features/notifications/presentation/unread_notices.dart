import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/notifications_repository.dart';

// One count for the whole client. Every tab draws the same bell, so the number
// behind it is read once here rather than once per tab.
//
// It is polled while the application is in front of the reader and left alone
// behind it: a phone nobody is looking at is told by push instead, and a timer
// running in the background spends battery to learn nothing.
class UnreadNotices extends LiveNotifier with WidgetsBindingObserver {
  UnreadNotices(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _watch();
  }

  static const Duration pollInterval = Duration(seconds: 30);

  final NotificationsRepository _repository;

  Timer? _poll;
  int _unread = 0;
  int _request = 0;

  int get unread => _unread;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch();
    } else {
      _stop();
    }
  }

  // A refusal leaves the count as it stands. The bell is not the screen a
  // network fault is worth reporting on, and the next poll says so anyway.
  Future<void> refresh() async {
    final int request = ++_request;

    try {
      final int unread = await _repository.unreadCount();

      // Only the newest read may write: an answer still in flight when a later
      // one is issued is stale by the time it lands.
      if (request == _request && unread != _unread && !isDisposed) {
        _unread = unread;
        publish();
      }
    } on ApiException {
      return;
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
