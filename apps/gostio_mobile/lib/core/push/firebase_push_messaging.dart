import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_messaging.dart';
import 'push_notice.dart';

// The one file in this client that imports the messaging package. Everything
// else is written against `PushMessaging`, so the whole registration and the
// tap that follows a delivery are tested without a service behind them.
//
// The service is started once, on the first thing asked of it. A build that
// carries no messaging configuration cannot start one, and that is answered
// with nothing rather than thrown: the notification row is written either way
// and the client reads it when it is opened.
//
// No background handler is registered, because none is needed. A message
// carrying a notification block is drawn by the platform while the application
// is behind the reader or shut; what this listens for is the tap that follows
// and the deliveries that arrive while the reader is in front of it.
class FirebasePushMessaging implements PushMessaging {
  final StreamController<String> _tokens = StreamController<String>.broadcast();

  // Two things read an arrival — the count and the list — so this one is
  // broadcast and an arrival nobody is listening for is dropped, which is
  // right: there is nothing to bring up to date.
  final StreamController<PushNotice> _arrivals =
      StreamController<PushNotice>.broadcast();

  // A tap has one reader at a time, and it is a new one after every sign-in,
  // so this is broadcast like the others. What broadcast cannot do is hold an
  // event nobody is listening for yet — and a tap that started the application
  // is exactly that — so the last one is kept until a reader arrives.
  final StreamController<PushNotice> _opened =
      StreamController<PushNotice>.broadcast();

  PushNotice? _untaken;

  final List<StreamSubscription<Object?>> _watching =
      <StreamSubscription<Object?>>[];

  Future<FirebaseMessaging?>? _starting;
  bool _isClosed = false;

  @override
  Stream<String> get deviceTokenChanges => _tokens.stream;

  @override
  Stream<PushNotice> get arrivals => _arrivals.stream;

  @override
  Stream<PushNotice> get opened async* {
    final PushNotice? untaken = _untaken;
    _untaken = null;
    if (untaken != null) {
      yield untaken;
    }

    yield* _opened.stream;
  }

  @override
  Future<String?> deviceToken() async {
    final FirebaseMessaging? service = await _service();

    try {
      return await service?.getToken();
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> askToDrawNotices() async {
    final FirebaseMessaging? service = await _service();

    try {
      // The answer is not branched on. A refused permission stops a notice
      // being drawn over the phone and changes nothing else: the row is still
      // written and the bell still counts it.
      await service?.requestPermission();
    } on Exception {
      return;
    }
  }

  @override
  Future<void> close() async {
    _isClosed = true;

    for (final StreamSubscription<Object?> watch in _watching) {
      await watch.cancel();
    }

    _watching.clear();
    await _tokens.close();
    await _arrivals.close();
    await _opened.close();
  }

  Future<FirebaseMessaging?> _service() => _starting ??= _start();

  Future<FirebaseMessaging?> _start() async {
    try {
      await Firebase.initializeApp();
    } on Exception {
      // A build without the messaging configuration beside it. Nothing is
      // registered and nothing is delivered; every other path is unaffected.
      return null;
    }

    final FirebaseMessaging service = FirebaseMessaging.instance;

    _watching.addAll(<StreamSubscription<Object?>>[
      service.onTokenRefresh.listen(_publishToken),
      FirebaseMessaging.onMessage.listen(_publishArrival),
      FirebaseMessaging.onMessageOpenedApp.listen(_publishOpened),
    ]);

    // The delivery that started the application. It is asked for after the
    // stream above is watched, so a tap taken while this was starting is not
    // lost between the two.
    final RemoteMessage? started = await service.getInitialMessage();
    if (started != null) {
      _publishOpened(started);
    }

    return service;
  }

  void _publishToken(String token) {
    if (!_isClosed) {
      _tokens.add(token);
    }
  }

  void _publishArrival(RemoteMessage message) {
    if (!_isClosed) {
      _arrivals.add(PushNotice.of(message.data));
    }
  }

  void _publishOpened(RemoteMessage message) {
    if (_isClosed) {
      return;
    }

    final PushNotice notice = PushNotice.of(message.data);

    if (_opened.hasListener) {
      _opened.add(notice);
    } else {
      _untaken = notice;
    }
  }
}
