import 'dart:async';

import 'package:flutter/widgets.dart';

// A read repeated on a timer while the application is in front of the reader,
// and stopped behind it: a phone nobody is looking at spends battery to learn
// nothing, and what it missed is asked for the moment it comes back rather than
// after the interval has run out.
//
// Two things in this client are kept current this way — the counts over the
// bell and the inbox tab, and the notice list while it is open — so the rule
// lives here and each of them owns one of these instead of keeping a timer and
// a lifecycle observer of its own.
class ForegroundPoll with WidgetsBindingObserver {
  ForegroundPoll(this._read) {
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _start();
    }
  }

  static const Duration interval = Duration(seconds: 30);

  final Future<void> Function() _read;

  Timer? _timer;

  // Coming back reads at once, because what arrived while the application was
  // away is the reason the reader opened it. Starting does not: whatever owns
  // this has its own first read to make, and two on one frame would be a
  // request nobody asked for.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
      unawaited(_read());
    } else {
      _stop();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
  }

  void _start() =>
      _timer ??= Timer.periodic(interval, (Timer _) => unawaited(_read()));

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
