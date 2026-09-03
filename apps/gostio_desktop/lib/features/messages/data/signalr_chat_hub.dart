import 'dart:async';

import '../../../core/network/api_client.dart';
import 'chat_broadcast.dart';
import 'chat_connection.dart';
import 'chat_hub.dart';
import 'message.dart';
import 'signalr_connection.dart';

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
  static const String _leave = 'Leave';

  final ChatConnections _open;

  final Map<int, StreamController<ChatEvent>> _watchers =
      <int, StreamController<ChatEvent>>{};

  ChatConnection? _connection;
  Future<ChatConnection>? _connecting;

  // Raised whenever the hub gives up what it holds; a connection landing
  // under an older number is one nothing waits for.
  int _generation = 0;

  bool _isClosed = false;

  @override
  Stream<ChatEvent> watch(int conversationId) {
    late final StreamController<ChatEvent> events;

    events = StreamController<ChatEvent>(
      onListen: () => unawaited(_joinThread(conversationId, events)),
      onCancel: () => _leaveThread(conversationId, events),
    );

    return events.stream;
  }

  @override
  Future<void> close() async {
    _isClosed = true;

    for (final StreamController<ChatEvent> watcher in _watchers.values) {
      unawaited(watcher.close());
    }
    _watchers.clear();

    await _hangUp();
  }

  Future<void> _joinThread(
    int conversationId,
    StreamController<ChatEvent> events,
  ) async {
    final StreamController<ChatEvent>? standing = _watchers[conversationId];
    if (standing != null && standing != events) {
      unawaited(standing.close());
    }

    _watchers[conversationId] = events;

    try {
      final ChatConnection connection = await _connect();

      // The thread can be left while this is connecting.
      if (_watchers[conversationId] != events) {
        return;
      }

      await connection.invoke(_join, <Object>[conversationId]);

      _tellWatcher(conversationId, events, const ChatJoined());
    } on Object catch (failure) {
      _tellWatcher(conversationId, events, ChatDropped(_reason(failure)));
    }
  }

  Future<void> _leaveThread(
    int conversationId,
    StreamController<ChatEvent> events,
  ) async {
    if (_watchers[conversationId] != events) {
      return;
    }

    _watchers.remove(conversationId);

    final ChatConnection? connection = _connection;

    if (connection != null && connection.isConnected) {
      try {
        await connection.invoke(_leave, <Object>[conversationId]);
      } on Object {
        // Nothing waits on it.
      }
    }

    if (_watchers.isEmpty) {
      await _hangUp();
    }
  }

  Future<ChatConnection> _connect() {
    final ChatConnection? standing = _connection;
    if (standing != null && standing.isConnected) {
      return Future<ChatConnection>.value(standing);
    }

    final Future<ChatConnection> connecting =
        _connecting ?? _start(_generation);
    _connecting = connecting;

    return connecting;
  }

  Future<ChatConnection> _start(int generation) async {
    try {
      return await _started(generation);
    } finally {
      // A hang-up may already have started another, not this one's to clear.
      if (generation == _generation) {
        _connecting = null;
      }
    }
  }

  Future<ChatConnection> _started(int generation) async {
    final ChatConnection connection = _open();

    connection.listen(
      said: (List<Object?>? arguments) => _said(connection, arguments),
      lost: (Object? failure) => _dropped(connection, failure),
      restored: () => _rejoin(connection),
    );

    await connection.start();

    if (_isClosed || generation != _generation) {
      await _stop(connection);

      throw const HubGivenUp();
    }

    return _connection = connection;
  }

  void _rejoin(ChatConnection connection) => unawaited(_rejoined(connection));

  Future<void> _rejoined(ChatConnection connection) async {
    if (!_isHeld(connection)) {
      return;
    }

    for (final MapEntry<int, StreamController<ChatEvent>> watched
        in _watchers.entries.toList(growable: false)) {
      try {
        await connection.invoke(_join, <Object>[watched.key]);

        _tellWatcher(watched.key, watched.value, const ChatJoined());
      } on Object catch (failure) {
        _tellWatcher(watched.key, watched.value, ChatDropped(_reason(failure)));
      }
    }
  }

  void _said(ChatConnection connection, List<Object?>? arguments) {
    if (!_isHeld(connection)) {
      return;
    }

    if (ChatBroadcast.read(arguments) case final Message said) {
      _tell(said.conversationId, ChatSaid(said));
    }
  }

  void _dropped(ChatConnection connection, Object? failure) {
    if (!_isHeld(connection)) {
      return;
    }

    final ChatDropped dropped = ChatDropped(_reason(failure));

    for (final StreamController<ChatEvent> watcher in _watchers.values) {
      _add(watcher, dropped);
    }
  }

  // Stopping a connection closes it, and a connection given up says nothing on
  // its way out: what it closes is not what the threads are on.
  bool _isHeld(ChatConnection connection) => _connection == connection;

  void _tell(int conversationId, ChatEvent event) {
    final StreamController<ChatEvent>? watcher = _watchers[conversationId];
    if (watcher != null) {
      _add(watcher, event);
    }
  }

  // A thread reopened mid-connect is a different watcher, and what the one
  // before it gave up is not its news.
  void _tellWatcher(
    int conversationId,
    StreamController<ChatEvent> events,
    ChatEvent event,
  ) {
    if (_watchers[conversationId] == events) {
      _add(events, event);
    }
  }

  // The number moves first, so a connection still being made gives itself up.
  Future<void> _hangUp() async {
    final ChatConnection? connection = _connection;

    _generation++;
    _connection = null;
    _connecting = null;

    await _stop(connection);
  }

  static void _add(StreamController<ChatEvent> watcher, ChatEvent event) {
    if (!watcher.isClosed) {
      watcher.add(event);
    }
  }

  static Future<void> _stop(ChatConnection? connection) async {
    if (connection == null) {
      return;
    }

    try {
      await connection.stop();
    } on Object {
      // A connection that will not be told it is over is over anyway.
    }
  }

  static String _reason(Object? failure) =>
      failure?.toString() ?? 'The hub connection closed.';
}

class HubGivenUp implements Exception {
  const HubGivenUp();

  @override
  String toString() => 'The hub was given up while it was connecting.';
}
