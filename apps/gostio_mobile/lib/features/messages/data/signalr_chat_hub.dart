import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import 'chat_broadcast.dart';
import 'chat_connection.dart';
import 'chat_hub.dart';
import 'signalr_connection.dart';

// One connection for one thread. The socket is opened when a thread is
// listened to and given up when that listen is cancelled, so a phone in a
// pocket holds nothing open and a thread left behind takes its socket with it.
//
// A watch that is no longer the one being held says nothing more. A connection
// still being made when the reader moves on is stopped as soon as it lands
// rather than left to announce a thread nobody is reading.
class SignalRChatHub implements ChatHub {
  SignalRChatHub(
    ApiClient client, {
    required Uri baseUrl,
    ChatConnections? open,
  }) : _open =
           open ??
           (() => SignalRConnection(
             address: '$baseUrl${ChatHub.path}',
             token: () => client.token,
           ));

  static const String _join = 'Join';

  final ChatConnections _open;

  _Watch? _held;
  bool _isClosed = false;

  @override
  Stream<ChatEvent> watch(int conversationId) {
    late final StreamController<ChatEvent> events;

    events = StreamController<ChatEvent>(
      onListen: () => unawaited(_start(_Watch(conversationId, events))),
      onCancel: () => _cancel(events),
    );

    return events.stream;
  }

  @override
  Future<void> close() async {
    _isClosed = true;

    await _giveUp(_take());
  }

  Future<void> _start(_Watch watch) async {
    await _giveUp(_take());

    if (_isClosed) {
      await watch.events.close();

      return;
    }

    _held = watch;

    final ChatConnection connection = _open()
      ..listen(
        said: (List<Object?>? arguments) => _said(watch, arguments),
        lost: (Object? failure) => _dropped(watch, failure),
        restored: () => unawaited(_rejoin(watch)),
      );
    watch.connection = connection;

    try {
      await connection.start();
      await connection.invoke(_join, <Object>[watch.conversationId]);

      if (!_isHeld(watch)) {
        await _hangUp(connection);

        return;
      }

      _tell(watch, const ChatJoined());
    } on Object {
      if (_isHeld(watch)) {
        _tell(watch, const ChatDropped());
      }
    }
  }

  // The socket came back on its own. The group it was in did not come with it,
  // so the thread is joined again before anything is delivered to it.
  Future<void> _rejoin(_Watch watch) async {
    final ChatConnection? connection = watch.connection;
    if (!_isHeld(watch) || connection == null) {
      return;
    }

    try {
      await connection.invoke(_join, <Object>[watch.conversationId]);

      if (_isHeld(watch)) {
        _tell(watch, const ChatJoined());
      }
    } on Object {
      if (_isHeld(watch)) {
        _tell(watch, const ChatDropped());
      }
    }
  }

  void _said(_Watch watch, List<Object?>? arguments) {
    if (!_isHeld(watch)) {
      return;
    }

    if (ChatBroadcast.read(arguments) case final Message said
        when said.conversationId == watch.conversationId) {
      _tell(watch, ChatSaid(said));
    }
  }

  void _dropped(_Watch watch, Object? _) {
    if (_isHeld(watch)) {
      _tell(watch, const ChatDropped());
    }
  }

  void _cancel(StreamController<ChatEvent> events) {
    final _Watch? held = _held;
    if (held != null && identical(held.events, events)) {
      unawaited(_giveUp(_take()));
    }
  }

  _Watch? _take() {
    final _Watch? held = _held;
    _held = null;

    return held;
  }

  bool _isHeld(_Watch watch) => identical(_held, watch);

  Future<void> _giveUp(_Watch? watch) async {
    if (watch == null) {
      return;
    }

    await watch.events.close();
    await _hangUp(watch.connection);
  }

  void _tell(_Watch watch, ChatEvent event) {
    if (!watch.events.isClosed) {
      watch.events.add(event);
    }
  }

  static Future<void> _hangUp(ChatConnection? connection) async {
    if (connection == null) {
      return;
    }

    try {
      await connection.stop();
    } on Object {
      // A connection that will not be told it is over is over anyway.
    }
  }
}

class _Watch {
  _Watch(this.conversationId, this.events);

  final int conversationId;
  final StreamController<ChatEvent> events;

  ChatConnection? connection;
}
